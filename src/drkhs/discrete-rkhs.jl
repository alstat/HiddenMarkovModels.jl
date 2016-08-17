
doc"""
    drkhs(n,rho=.5)

Return the kernel function with 1 on the diagonal, ``\rho`` on the subdiagonals and 0 elsewhere, 
meant to be used as an example of a noncanonical discrete RKHS.  
"""
function drkhs(n,rho=.5)
    k=eye(n,n)
    for i=1:n-1
        k[i+1,i]=rho
        k[i,i+1]=rho
    end
    k
end

# ip{f}{f'} in H is given by f*w*f', w=inv(k)
# u=sqrtm(Symmetric(k))    #orthonormal basis in H, with u[i,j]= u_j(i)

# A basis for T_1 \otimes T_2 is (u_1 \otimes v_1), (u_1 \otimes v_2),.. (in this order).
# The "inner" index (which moves more frequently) is j on v_j. This is the opposite of vec(m[i,j]).


#Here u*m*kron(u'*w*g1,u'*w*g2)=g1.*g2
# and m*kron(u'*w*g,[1,0,0,0]) = mg*[1,0,0,0]
doc"""
    mult(k,u)

For the RKHS ``k``, return the multiplication operator in ``u`` coordinates. 
`mult` is a operator in ``B(H \otimes H,H)``, ie. a matrix of size (``n \times n^2``).
By definition `u*m*kron(u'*w*g1,u'*w*g2)==g1.*g2`.
"""
function mult(k,u)
    n=size(k,1)
    m=zeros(n,n,n)
    for i=1:n
        for j=1:n
            m[:,j,i]=u'*(k\(u[:,i].*u[:,j]))
        end
    end
    reshape(m,n,n^2)
end



#Here cmg*u[:,1]=g.*u[:,1]=u2*mg*[1,0,0,0]
doc"""
    mg(k,u,g)

For a function ``g`` in the RKHS ``k``, return the operator ``M_g`` in ``u`` coordinates.
``g`` is expressed pointwise, ie. g[j]=g(j).
If ``f`` is expressed in ``u``, ``M_g f`` is ``fg`` expressed in ``u``. 
"""
mg(k,u,g)=u'*(k\diagm(g))*u

doc"""
    mtf(k,u,f)

For a function ``f`` in the RKHS ``k``, return the operator ``\tilde{M}_f`` in ``u`` coordinates. 
``f`` is expressed pointwise, ie. f[i]=f(i).
"""
function mtf(k,u,f)
    n=size(k,1)
    mtf=zeros(n,n)
    for j=1:n
        for i=1:n
            mtf[i,j]=(f'*(k\(u[:,i].*u[:,j])))[1]
        end
    end
    mtf
end


doc"""
    fmu(k,mu)

Find the representant of the measure ``mu`` in the RKHS ``k``. 
``mu`` and ``fmu(k,mu)`` are expressed pointwise.
"""
fmu(mu,k)=vec(k*mu')


#the following assumes "mu" is a measure, and is equal to m-tilde(f_mu)
#it is NOT m-tilde(mu), mu seen as a function
#Of course here trace(mtmu(mu,k)*mg(k,f)) = mu*f


doc"""
    mtmu(k,u,mu)

For a measure ``mu`` in the RKHS ``k``, return the operator ``\tilde{M}_\mu`` in ``u`` coordinates.
``mu`` is expressed pointwise.
This is the same as computing mtf(k,u,fmu(k,mu)).
"""
function mtmu(k,u,mu)
    u=sqrtm(k)
    n=size(k,1)
    w=inv(k)
    mtmu=zeros(n,n)
    for j=1:n
        for i=1:n
            mtmu[i,j]=(mu*(u[:,i].*u[:,j]))[1]
        end
    end
    mtmu
end


doc"""
    incl(k,u)

For a RKHS ``k``, return the operator ``f \to vec(M_f)`` in ``u`` coordinates.
By definition `vec(mg(k,u,f))==incl(k,u)*u'*(k\f)`.
"""
function incl(k,u)
    n=size(k,1)
    j=zeros(n^2,n)
    for i=1:n
        j[:,i]=vec(mg(k,u,u[:,i]))
    end
    j
end

doc"""
    inclt(k,u)

For a RKHS ``k``, return the operator ``f \to vec( \tilde{M}_f)`` in ``u`` coordinates.
By definition `vec(mtf(k,u,f))==incl(k,u)*u'*(k\f)`.
"""
function inclt(k,u)
    n=size(k,1)
    j=zeros(n^2,n)
    for i=1:n
        j[:,i]=vec(mtf(k,u,u[:,i]))
    end
    j
end

doc"""
    qdual(k1,u1,u2,q)

Return the operator expression of ``g(y) \in H_{k_2} \to Q(x,dy)g(y) \in H_{k_1}`` 
between RKHSs `k1` and `k2` with bases `u1` and `u2`.    
"""
qdual(k1,u1,u2,q)=u1'*(k1\q)*u2  

doc"""
    qchannel(k1,u1,u2,q)

Return the operator which sends ``f_\mu`` in `k1` to ``g_{\mu Q}`` in `k2`, 
expressed in `u1` and `u2` coordinates.    
"""
qchannel(k1,u1,u2,q)=qdual(k1,u1,u2,q)'






