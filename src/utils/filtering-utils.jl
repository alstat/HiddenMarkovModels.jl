

# API for common update functions 
upq(mu,q)=vec(mu'*q)  # Markov kernel
upf(mu,f)=normalize(mu.*f,1)  # Boltzman Gibbs update
upr(mu,r)=normalize(vec(mu'*r),1)  # positive operator




# Diagnostic functions

function coefvar(w)
    tot=sum(w)
    n=length(w)
    sqrt(mean((n*(w/tot)-1).^2))
end

function ess(w)
    n=length(w)
    n/(1+coefvar(w)^2)
end

function relerror(q1,q2,ky)
    nx=size(q1,1)
    err=zeros(nx)
    for ix=1:nx
        dmui=q1[ix,:]-q2[ix,:]
        err[ix]=sqrt(dot(dmui,ky*dmui))
    end
    err
end









