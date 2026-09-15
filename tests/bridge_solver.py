"""Independent BFS: positions, departed-cell masks per core, active core, keys."""
from collections import deque
class Puzzle:
 def __init__(self,s):
  self.s=s;self.w=s['width'];self.h=s['height'];self.n=self.w*self.h
  self.encode=lambda p:p[1]*self.w+p[0]
  self.xy=lambda i:[i%self.w,i//self.w]
  self.goals=tuple(map(self.encode,s['goals']));self.walls=sum(1<<self.encode(p) for p in s['walls'])
  self.start=(*map(self.encode,s['starts']),0,0,0,0)
  self.limit=s['step_limit']
  self.arrows={self.encode(t):tuple(t[2:]) for t in s.get('arrows',[])}
  self.stops={self.encode(t) for t in s.get('stops',[])}
  self.bridges={self.encode(t):t[2] for t in s.get('bridges',[])}
  self.keys={self.encode(t):t[2] for t in s.get('keys',[])}
  self.gates={self.encode(t):t[2] for t in s.get('gates',[])}
  self.adj={i:[j for j in (i-1,i+1,i-self.w,i+self.w) if 0<=j<self.n and abs(i%self.w-j%self.w)+abs(i//self.w-j//self.w)==1] for i in range(self.n)}
 def allowed(self,x,y):
  return x not in self.arrows or (y%self.w-x%self.w,y//self.w-x//self.w)==self.arrows[x]
 def blocked(self,c,state,who,optimistic=False):
  a,b,ma,mb,t,k=state
  if self.walls>>c&1:return True
  if not optimistic and c in self.gates and not k>>self.gates[c]&1:return True
  mine=(ma,mb)[who];other=(ma,mb)[1-who]
  if c in self.bridges:
   if mine>>c&1:return True
   if other>>c&1:return False
   return self.bridges[c]!=who and not optimistic
  return bool((ma|mb)>>c&1)
 def reachable(self,state,who):
  a,b,ma,mb,t,k=state;p=(a,b)[who];other=(a,b)[1-who];goal=self.goals[who]
  if p==goal:return True
  seen={p};q=[p]
  for x in q:
   for y in self.adj[x]:
    if not self.allowed(x,y) or y in seen or self.blocked(y,state,who,True):continue
    if (y==other and y not in self.bridges) or y==self.goals[1-who]:continue
    if y==goal:return True
    seen.add(y);q.append(y)
  return False
 def actions(self,state):
  a,b,ma,mb,turn,key=state;ps=[a,b];other=ps[1-turn];goal=self.goals[turn]
  def walk(path,used):
   if len(path)>1:
    newpos=ps[:];newpos[turn]=path[-1];masks=[ma,mb];nk=key
    for c in path[:-1]:masks[turn]|=1<<c
    for c in path:
     if c in self.keys:nk|=1<<self.keys[c]
    nt=1-turn
    if newpos[nt]==self.goals[nt]:nt=turn
    yield (*newpos,*masks,nt,nk),path[:]
   if len(path)-1==self.limit or path[-1]==goal or (len(path)>1 and path[-1] in self.stops):return
   for nxt in self.adj[path[-1]]:
    if nxt==other or nxt==self.goals[1-turn] or nxt in used or not self.allowed(path[-1],nxt) or self.blocked(nxt,state,turn):continue
    yield from walk(path+[nxt],used|{nxt})
  yield from walk([ps[turn]],{ps[turn]})
 def solve(self,initial=None,budget=60000):
  initial=initial or self.start;q=deque([initial]);prev={initial:None}
  while q:
   state=q.popleft()
   if state[:2]==self.goals:
    sol=[]
    while prev[state]:
     old,path=prev[state];sol.append({'core':old[4],'path':[self.xy(x) for x in path]});state=old
    return sol[::-1],len(prev)
   for nxt,path in self.actions(state):
    if nxt in prev or not all(self.reachable(nxt,i) for i in (0,1)):continue
    prev[nxt]=(state,path);q.append(nxt)
    if len(prev)>budget:return None,len(prev)
  return None,len(prev)
if __name__=='__main__':
 import json
 for s in json.load(open('data/stages.json')):
  sol,states=Puzzle(s).solve(budget=300000)
  assert sol and len(sol)==s['par_moves'],s['stage_id']
  print(s['stage_id'],len(sol),states,flush=True)
