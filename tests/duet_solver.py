"""Independent exhaustive turn solver for TRACE SHIFT: DUET."""
from collections import deque

class Puzzle:
 def __init__(self,s):
  self.s=s;self.w=s['width'];self.h=s['height'];self.n=self.w*self.h
  self.encode=lambda p:p[1]*self.w+p[0]
  self.xy=lambda i:[i%self.w,i//self.w]
  self.goals=tuple(map(self.encode,s['goals']))
  self.start=(*map(self.encode,s['starts']),sum(1<<self.encode(p) for p in s['walls']),0)
  self.limit=s['step_limit']
  self.arrows={self.encode(t[:2]):tuple(t[2:]) for t in s.get('arrows',[])}
  self.stops={self.encode(t) for t in s.get('stops',[])}
  self.adj={i:[j for j in (i-1,i+1,i-self.w,i+self.w) if 0<=j<self.n and abs(i%self.w-j%self.w)+abs(i//self.w-j//self.w)==1] for i in range(self.n)}
 def allowed(self,x,y):
  return x not in self.arrows or (y%self.w-x%self.w,y//self.w-x//self.w)==self.arrows[x]
 def reachable(self,state,who):
  a,b,mask,turn=state; p=(a,b)[who];other=(a,b)[1-who];goal=self.goals[who]
  if p==goal:return True
  seen={p};q=[p]
  for x in q:
   for y in self.adj[x]:
    if not self.allowed(x,y):continue
    if y==other or y==self.goals[1-who] or mask>>y&1 or y in seen:continue
    if y==goal:return True
    seen.add(y);q.append(y)
  return False
 def actions(self,state):
  a,b,mask,turn=state;ps=[a,b];other=ps[1-turn];goal=self.goals[turn]
  def walk(path,used):
   if len(path)>1:
    newpos=ps[:];newpos[turn]=path[-1]
    newmask=mask
    for c in path[:-1]:newmask|=1<<c
    nt=1-turn
    if newpos[nt]==self.goals[nt]:nt=turn
    yield (*newpos,newmask,nt),path[:]
   if len(path)-1==self.limit or path[-1]==goal or (len(path)>1 and path[-1] in self.stops):return
   for nxt in self.adj[path[-1]]:
    if not self.allowed(path[-1],nxt):continue
    if nxt==other or nxt==self.goals[1-turn] or mask>>nxt&1 or nxt in used:continue
    yield from walk(path+[nxt],used|{nxt})
  yield from walk([ps[turn]],{ps[turn]})
 def solve(self,initial=None,budget=100000):
  initial=initial or self.start
  q=deque([initial]);prev={initial:None}
  while q:
   state=q.popleft()
   if state[:2]==self.goals:
    sol=[]
    while prev[state]:
     old,path=prev[state];sol.append({'core':old[3],'path':[self.xy(x) for x in path]});state=old
    return sol[::-1],len(prev)
   for nxt,path in self.actions(state):
    if nxt in prev:continue
    if not all(self.reachable(nxt,i) for i in (0,1)):continue
    prev[nxt]=(state,path);q.append(nxt)
    if len(prev)>budget:return None,len(prev)
  return None,len(prev)
 def shortest(self,who):
  a,b,mask,t=self.start; start=(a,b)[who];goal=self.goals[who];q=deque([(start,0)]);seen={start}
  while q:
   p,d=q.popleft()
   if p==goal:return d
   for n in self.adj[p]:
    if n in seen or mask>>n&1 or n==(a,b)[1-who] or n==self.goals[1-who]:continue
    seen.add(n);q.append((n,d+1))
  return 1000

if __name__=='__main__':
 import json
 stages=json.load(open('data/stages.json'))
 for s in stages:
  p=Puzzle(s);sol,states=p.solve()
  assert sol and len(sol)==s['par_moves'],s['stage_id']
  print(s['stage_id'],s['name'],'optimal',len(sol),'states',states)
