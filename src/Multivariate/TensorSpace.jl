
export TensorSpace,⊗,ProductSpace

#  SV is a tuple of d spaces
abstract AbstractProductSpace{SV,T,d} <: Space{T,AnyDomain,d}


spacetype{SV}(::AbstractProductSpace{SV},k) = SV.parameters[k]


# TensorIterator
# This gives the map from coefficients to the
# tensor entry of a tensor product of d spaces
# findfirst is overriden to get efficient inverse

immutable TensorIterator{d} end


Base.eltype{d}(::TensorIterator{d}) = NTuple{d,Int}


Base.start(::TensorIterator{2}) = (1,1)
Base.start(::TensorIterator{3}) = (1,1,1)
Base.start{d}(::TensorIterator{d}) = tuple(ones(Int,d)...)::NTuple{d,Int}

Base.next(::TensorIterator{2},st::Tuple{Int,Int}) =
    (st,st[2] == 1? (1,st[1]+1) : (st[1]+1,st[2]-1))

Base.done(::TensorIterator,st) = false

function Base.findfirst(::TensorIterator{2},kj::Tuple{Int,Int})
    k,j=kj
    n=k+j-2
    (n*(n+1))÷2+k
end

# which block of the tensor
# equivalent to sum of indices -1
tensorblock(::TensorIterator{2},n) = floor(Integer,sqrt(2n) + 1/2)


function getindex(it::TensorIterator{2},n::Integer)
    m=tensorblock(it,n)
    p=findfirst(it,(1,m))
    j=1+n-p
    j,m-j+1
end


# TensorSpace
# represents the tensor product of several subspaces

immutable TensorSpace{SV,T,d} <:AbstractProductSpace{SV,T,d}
    spaces::SV
end

tensorizer{SV,T,d}(::TensorSpace{SV,T,d}) = TensorIterator{d}()

TensorSpace(sp::Tuple) =
    TensorSpace{typeof(sp),mapreduce(basistype,promote_type,sp),mapreduce(ndims,+,sp)}(sp)

for OP in (:spacescompatible,:(==))
    @eval $OP{SV,T,d}(A::TensorSpace{SV,T,d},B::TensorSpace{SV,T,d}) =
        all(Bool[$OP(A.spaces[k],B.spaces[k]) for k=1:length(A.spaces)])
end

canonicalspace(T::TensorSpace) = TensorSpace(map(canonicalspace,T.spaces))




coefficient_type(S::TensorSpace,T) =
    mapreduce(sp->coefficient_type(sp,T),promote_type,S.spaces)

TensorSpace(A...) = TensorSpace(tuple(A...))
TensorSpace(A::ProductDomain) = TensorSpace(tuple(map(Space,A.domains)...))
⊗(A::TensorSpace,B::TensorSpace) = TensorSpace(A.spaces...,B.spaces...)
⊗(A::TensorSpace,B::Space) = TensorSpace(A.spaces...,B)
⊗(A::Space,B::TensorSpace) = TensorSpace(A,B.spaces...)
⊗(A::Space,B::Space) = TensorSpace(A,B)

domain(f::TensorSpace) = mapreduce(domain,*,f.spaces)
Space(sp::ProductDomain) = TensorSpace(sp)

*(A::Space,B::Space) = A⊗B


# every column is in the same space for a TensorSpace
#TODO: remove
columnspace(S::TensorSpace,::) = S.spaces[1]

Base.length(d::TensorSpace) = length(d.spaces)
Base.getindex(d::TensorSpace,k::Integer) = d.spaces[k]


immutable ProductSpace{S<:Space,V<:Space,T} <: AbstractProductSpace{Tuple{S,V},T,2}
    spacesx::Vector{S}
    spacey::V
end

ProductSpace(spacesx::Vector,spacey)=ProductSpace{eltype(spacesx),
                                                  typeof(spacey),
                                                  promote_type(basistype(first(spacesx)),basistype(spacey))}(spacesx,spacey)

coefficient_type(S::ProductSpace,T) =
    promote_type(coefficient_type(S.spacesx[1],T),coefficient_type(S.spacesy,T))

⊗{S<:Space}(A::Vector{S},B::Space) = ProductSpace(A,B)
domain(f::ProductSpace) = domain(f.spacesx[1])*domain(f.spacesy)

Base.getindex(d::ProductSpace,k::Integer) = k==1?d.spacesx:d.spacey


space(d::AbstractProductSpace,k) = d[k]
isambiguous(A::TensorSpace) = isambiguous(A[1])||isambiguous(A[2])


Base.transpose(d::TensorSpace) = TensorSpace(d[2],d[1])





##Transforms

plan_column_transform(S,v) = plan_transform(columnspace(S,1),v)
plan_column_itransform(S,v) = plan_itransform(columnspace(S,1),v)

function itransform!(S::TensorSpace,M::Matrix)
    n=size(M,1)

    planc=plan_itransform(space(S,1),M[:,1])
    for k=1:size(M,2)
        M[:,k]=itransform(space(S,1),M[:,k],planc)
    end

    planr=plan_itransform(space(S,2),vec(M[1,:]))
    for k=1:n
        M[k,:]=itransform(space(S,2),vec(M[k,:]),planr)
    end
    M
end

function itransform!(S::AbstractProductSpace,M::Matrix)
    n=size(M,1)

    ## The order matters
    pln=plan_column_itransform(S,n)
    for k=1:size(M,2)
        M[:,k]=itransform(columnspace(S,k),M[:,k],pln)
    end

    for k=1:n
        M[k,:]=itransform(space(S,2),vec(M[k,:]))
    end
    M
end

function transform!(S::TensorSpace,M::Matrix)
    n=size(M,1)

    planc=plan_transform(space(S,1),M[:,1])
    for k=1:size(M,2)
        M[:,k]=transform(space(S,1),M[:,k],planc)
    end

    planr=plan_transform(space(S,2),vec(M[1,:]))
    for k=1:n
        M[k,:]=transform(space(S,2),vec(M[k,:]),planr)
    end
    M
end

function transform!{T}(S::AbstractProductSpace,M::Matrix{T})
    n=size(M,1)

    ## The order matters!!
    # For Disk Space, this is due to requiring decay
    # in function
    for k=1:n
        M[k,:]=transform(space(S,2),vec(M[k,:]))
    end

    pln=plan_column_transform(S,n)
    for k=1:size(M,2)
        # col may not be full length
        col=transform(columnspace(S,k),M[:,k],pln)
        M[1:length(col),k]=col
        for j=length(col)+1:n
            M[j,k]=zero(T) # fill rest with zeros
        end
    end


    M
end



## points

points(d::Union{BivariateDomain,BivariateSpace},n,m) =
    points(d,n,m,1),points(d,n,m,2)

function points(d::BivariateSpace,n,m,k)
    ptsx=points(columnspace(d,1),n)
    ptst=points(space(d,2),m)

    promote_type(eltype(ptsx),eltype(ptst))[fromcanonical(d,x,t)[k] for x in ptsx, t in ptst]
end




##  Fun routines

function fromtensor{T}(it::TensorIterator{2},M::Matrix{T})
    ret=zeros(T,findfirst(it,(size(M,1),size(M,2))))
    for k=1:size(M,1),j=1:size(M,2)
        ret[findfirst(it,(k,j))] = M[k,j]
    end
    ret
end

function totensor{T}(it::TensorIterator{2},M::Vector{T})
    inds=it[length(M)]
    m=inds[1]+inds[2]-1
    ret=zeros(T,m,m)
    for k=1:length(M)
        ret[it[k]...] = M[k]
    end
    ret
end

for OP in (:fromtensor,:totensor)
    @eval $OP(s::Space,M) = $OP(tensorizer(s),M)
end

# TODO: remove
function totree(v::Vector)
   m=totensorblock(length(v))
    r=Array(Vector{eltype(v)},m)
    for k=1:m-1
        r[k]=v[fromtensorblock(k)]
    end
    r[m]=pad!(v[fromtensorblock(m)[1]:end],m)
    r
end

fromtree{T}(v::Vector{Vector{T}}) = vcat(v...)

function points(sp::TensorSpace,n)
    pts=Array(Tuple{Float64,Float64},0)
    for x in points(sp[1],round(Int,sqrt(n))), y in points(sp[2],round(Int,sqrt(n)))
        push!(pts,(x,y))
    end
    pts
end

function transform(sp::TensorSpace,vals)
    m=round(Int,sqrt(length(vals)))
    M=reshape(copy(vals),m,m)

    fromtensor(transform!(sp,M))
end

evaluate(f::AbstractVector,S::AbstractProductSpace,x) = ProductFun(totensor(f),S)(x...)
evaluate(f::AbstractVector,S::AbstractProductSpace,x,y) = ProductFun(totensor(f),S)(x,y)



coefficientmatrix{S<:AbstractProductSpace}(f::Fun{S}) = totensor(f.coefficients)

Fun{T<:Number}(v::Vector{Vector{T}},S::TensorSpace) = Fun(fromtree(v),S)


#TODO: Implement
# function ∂(d::TensorSpace{Interval{Float64}})
#     @assert length(d.spaces) ==2
#     PiecewiseSpace([d[1].a+im*d[2],d[1].b+im*d[2],d[1]+im*d[2].a,d[1]+im*d[2].b])
# end


union_rule(a::TensorSpace,b::TensorSpace) = TensorSpace(map(union,a.spaces,b.spaces))
