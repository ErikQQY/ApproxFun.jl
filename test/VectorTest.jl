using ApproxFun,Base.Test

import ApproxFun:interlace


d=Interval()
D=Derivative(d);
B=ldirichlet();
Bn=lneumann();
A=[B 0;
   0 B;
   D-I 2.I;
   0 D+I];

f=Fun(x->[exp(x),cos(x)],d)


b1=Any[0.,0.,f]
f1=vec(f)[1];f2=vec(f)[2];
b2=Any[0.,0.,f1,f2]



for b in (b1,b2)
    u=A\b
    u1=vec(u)[1];u2=vec(u)[2];

    @test norm(diff(u1)-u1+2.u2-f1)<eps()
    @test norm(diff(u2)+u2-f2)<eps()    

    Ai=interlace(A)
    u=Ai\b
    u1=vec(u)[1];u2=vec(u)[2];

    @test norm(diff(u1)-u1+2.u2-f1)<eps()
    @test norm(diff(u2)+u2-f2)<eps()
end





A=[B 0;
   Bn 0;
   0 B;
   D^2-I 2.I;
   0 D+I];
   
   
b1=Any[0.,0.,0.,f]
f1=vec(f)[1];f2=vec(f)[2];
b2=Any[0.,0.,0.,f1,f2]



for b in (b1,b2)
    u=A\b
    u1=vec(u)[1];u2=vec(u)[2];


    @test norm(diff(u1,2)-u1+2.u2-f1)<2eps()
    @test norm(diff(u2)+u2-f2)<2eps()
    
    Ai=interlace(A)
    u=Ai\b
    u1=vec(u)[1];u2=vec(u)[2];


    @test norm(diff(u1,2)-u1+2.u2-f1)<2eps()
    @test norm(diff(u2)+u2-f2)<2eps()
end





## Matrix exponential

n=4
d=fill(Interval(0.,1.),n)
B=Evaluation(d,0.)
D=Derivative(d)
A=rand(n,n)
L=[B;D-A]
u=L\eye(n)
@test norm(evaluate(u,1.)-expm(A))<eps(1000.)





## Multiplication

d = Interval()
t=Fun(identity,d)
f = devec([t^2, sin(t)])
@test norm(((Derivative(space(f))*f)-Fun(t->[2t,cos(t)])).coefficients)<100eps()
@test norm((([1 2;3 4]*f)-Fun(t->[t^2+2sin(t),3t^2+4sin(t)])).coefficients)<100eps()



## Multiplication operator

Γ=Circle()∪Circle(0.5)
G=Fun(z->in(z,Γ[2])?[1 -z^(-1); 0 1]:
                   [z 0; 0 z^(-1)],Γ);
G1=demat(mat(G)[:,1])
M=Multiplication(G,space(G1))
u=M*G1
@test norm(u[exp(.1im)]-[exp(.2im),0])<100eps()
@test norm(u[.5exp(.1im)]-[1,0])<100eps()


