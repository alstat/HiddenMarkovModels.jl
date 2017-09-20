################################################################################################
### RKHS spaces
################################################################################################

abstract AtomicRKHS
typealias RKHS NestedTuple{AtomicRKHS}

rkhs{H <: RKHS}(::Type{H})=instantiate(H)

################################################################################################
### RKHS Bases
################################################################################################


immutable RKHSBasis{H <: RKHS,T}
	points::Vector{T}
end

RKHSBasis{T}(H::RKHS,points::Vector{T})=RKHSBasis{typeof(H),T}(points)



length(b::RKHSBasis)=length(b.points)
rkhs{H}(b::RKHSBasis{H})=rkhs(H)   #Or further down the road b.space if spaces end up needing inner fields


################################################################################################
### RKHS Vectors and maps
################################################################################################

# Vectors in RKHS spaces are represented as linear combinations of basis vectors.
# As of now only k_x are allowed to be basis vectors.
# As a consequence they can be stored as `x` from the ground space.
# Note that k_x is also the embedding for delta_x, the Dirac measure at x. 
immutable RKHSVector{H <: RKHS,T}
	#Do I want abstract vector types (sparsity...) and abstract number types (ForwardDiff...) for weights? 
	weights::Vector{Float64}    
	basis::RKHSBasis{H,T}
	function RKHSVector(weights,basis)
		@assert length(weights)==length(basis)
		new(weights,basis)
	end
end

RKHSVector{H,T}(weights,basis::RKHSBasis{H,T})=RKHSVector{H,T}(weights,basis)

rkhs(v::RKHSVector)=rkhs(v.basis)
# length(v::RKHSVector)=length(v.weights)


immutable RKHSMap{H1 <: RKHS,H2 <: RKHS,T1,T2}
	leftbasis::RKHSBasis{H1,T1}
	weights::Matrix{Float64}    
	rightbasis::RKHSBasis{H2,T2}
	function RKHSMap(leftbasis,weights,rightbasis )
		@assert size(weights)==(length(leftbasis),length(rightbasis))
		new(leftbasis,weights,rightbasis)
	end
end

RKHSMap{H1,H2,T1,T2}(leftbasis::RKHSBasis{H1,T1},weights,rightbasis::RKHSBasis{H2,T2})=RKHSMap{H1,H2,T1,T2}(leftbasis,weights,rightbasis)



################################################################################################
### KERNEL FUNCTIONS
################################################################################################


# TODO: optimize (smarter iterator?) if bottleneck
#For vector of elements (bases)
function gramian(H::RKHS,x::AbstractVector,y::AbstractVector)
	lx=length(x)
	ly=length(y)
	[kernel(H,x[ix],y[jy]) for ix=1:lx,jy=1:ly]
	# res=zeros(lx,ly)
	# for jy=1:ly
	# 	for ix=1:lx
	# 		# @code_warntype(kernel(H,x[ix],y[jy]))
	# 		# error()
	# 		res[ix,jy]=kernel(H,x[ix],y[jy])
	# 	end
	# end
	# res
end

function gramian{H}(basis1::RKHSBasis{H},basis2::RKHSBasis{H})
	gramian(rkhs(H),basis1.points,basis2.points)
end

# TYPE STABILITY ANALYSIS:
# The only type instability I can see is that getindex(Tuple{T1,T2}) -> Union{T1,T2}
# which kicks in when I call H[i]
# For individual elements:
function kernel(H::Tuple{Vararg{RKHS}},x::Tuple,y::Tuple)
	res=1.0
	for i=1:length(H)
		res=res*kernel(H[i],x[i],y[i])
	end
	res
end

function dimension(H::Tuple{Vararg{RKHS}})
	if length(H)>1
		return dimension(H[1])+dimension(H[2:end])
	else
		return dimension(H[1])
	end
end


immutable KernelDistance{H <: RKHS} <: Distance
	# If RKHSs end up being objects, I will need the rkhs field.
	# I could get rid of it now, except that my test/example code uses it.
	rkhs::H   
end

rkhs{T,D <: KernelDistance}(tree::VPTree{T,D})=rkhs(D)
# rkhs(D::KernelDistance)=D.rkhs   # If RKHSs end up being objects
rkhs{H}(D::KernelDistance{H})=rkhs(H)

#This is to compute d(delta_xx,delta_yy) = d(xx,yy) by abuse of notation.
#Two cases: xx is a Point or xx is a Tuple{Vararg{Point}}
#In both cases xx and yy must have the same type
#I don't dispatch here on Union{Point,Tuple{Vararg{Point}}}, `kernel()` will make the proper checks downstream
evaluate(dk::KernelDistance,x,y)=sqrt(kernel(rkhs(dk),x,x)+kernel(rkhs(dk),y,y)-2*kernel(rkhs(dk),x,y))



# immutable KernelDistanceWithGramian{H <: RKHS} <: Distance
# 	# If RKHSs end up being objects, I will need the rkhs field.
# 	# I could get rid of it now, except that my test/example code uses it.
# 	gram::Matrix{Float64}
# 	rkhs::H   
# end

# rkhs{T,D <: KernelDistanceWithGramian}(tree::VPTree{T,D})=rkhs(D)
# # rkhs(D::KernelDistance)=D.rkhs   # If RKHSs end up being objects
# rkhs{H}(D::KernelDistanceWithGramian{H})=rkhs(H)

# evaluate(dk::KernelDistanceWithGramian,i,j)=sqrt(dk.gram[i,i]+dk.gram[j,j]-2*dk.gram[i,j])

immutable RKHSBasisTree{H <: RKHS, T,D <: KernelDistance} 
	tree::VPTree{T,D}
	gram::Matrix{Float64}
end

#is there a simpler expression?
function gramian2distances(gramian)
	n=size(gramian,1)
	[sqrt(gramian[i,i]+gramian[j,j]-2*gramian[i,j]) for i=1:n,j=1:n]
end

function RKHSBasisTree{H,T}(basis::RKHSBasis{H,T},gramian::Matrix{Float64})
	distance_table=gramian2distances(gramian)
	tree=VPTree(basis.points, KernelDistance(rkhs(basis)),distance_table)
	RKHSBasisTree{H,T,KernelDistance{H}}(tree,gramian)
end

RKHSBasisTree{H,T}(basis::RKHSBasis{H,T})=RKHSBasisTree(basis,gramian(basis,basis))


rkhs{H}(basistree::RKHSBasisTree{H})=rkhs(H)


################################################################################################
### SOME CONCRETE RKHS SPACES
################################################################################################


# For now a space type carries all the relevant information in the type.
# This way a Point{H} carries all the information in its type
immutable GaussianRKHS{Dimension,Precision,Label} <: AtomicRKHS
	# dimension::Int
	# precision::Float64
end

dimension{N}(H::GaussianRKHS{N})=N
precision{N,P}(H::GaussianRKHS{N,P})=P


#could add an `@assert dimension(H)=length(x)` but might be too slow
kernel(H::GaussianRKHS,x::Vector{Float64},y::Vector{Float64})=exp(-precision(H)*norm(x-y)/2)

kernel(H::GaussianRKHS{1},x::Float64,y::Float64)=exp(-precision(H)*norm(x-y)/2)

immutable DiscreteRKHS{Label} <: AtomicRKHS end

dimension(H::DiscreteRKHS)=1

kernel(H::DiscreteRKHS,x::Int,y::Int)=(1.0*(x==y))


immutable LaplaceRKHS{Label} <: AtomicRKHS
	# dimension::Int
	# precision::Float64
end

dimension(H::LaplaceRKHS)=1

kernel(H::LaplaceRKHS,x::Float64,y::Float64)=exp(-abs(x-y))



immutable GuilbartRKHS{H <: RKHS,Label} <: AtomicRKHS
	# ground::H
end

dimension(H::GuilbartRKHS)=5  #this is a hack: dimension is mostly used to choose 2*dim nearest neighbours 

function kernel{subH}(H::GuilbartRKHS{subH},x::RKHSVector{subH},y::RKHSVector{subH})
	#can have speed gain here by using symmetry
	basispoints=vcat(x.basis.points,y.basis.points)
	weights=vcat(x.weights,-y.weights)
	gram=gramian(rkhs(subH),basispoints,basispoints)
	exp(-sqrt(abs(dot(weights,gram*weights))))
end

