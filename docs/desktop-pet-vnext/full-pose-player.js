const $ = id => document.getElementById(id);
const states = ['work', 'rest'];
const labels = {work:'专注 · 敲键盘', rest:'休息 · 喝口茶'};
const captions = {work:'电脑放在腿上，两只手交替敲键盘。', rest:'坐下捧杯，举起喝一口，再慢慢放回。'};
const stage=$('desktop'),pet=$('pet'),cards=[];
let metadata, atlases={}, state='work', ready=false,playing=true,reduced=matchMedia('(prefers-reduced-motion:reduce)').matches;
let entered=performance.now(),elapsed=0,frame=0,height=80,raf=null,x=0,y=0,userMoved=false,drag=null;
let lastKey='';
$('reduce').checked=reduced;
for(const s of states){
 const button=document.createElement('button');button.textContent=labels[s];button.dataset.state=s;button.addEventListener('click',()=>select(s));$('modes').append(button);
 const card=document.createElement('button');card.setAttribute('aria-label',labels[s]+'动作对照');card.innerHTML='<canvas width="288" height="288"></canvas><span>'+labels[s]+'</span>';card.addEventListener('click',()=>select(s));$('overview').append(card);cards.push({state:s,element:card});
}
function frameAt(s,t){const timeline=metadata[s].timeline,cycle=timeline.reduce((a,b)=>a+b.duration,0);let at=t%cycle;for(const step of timeline){if(at<step.duration)return step.frame;at-=step.duration;}return 0;}
function drawSprite(canvas,s,index){
 const c=canvas.getContext('2d'),m=metadata[s],side=canvas.width,[left,top,right,bottom]=m.bounds;
 c.setTransform(1,0,0,1,0,0);c.clearRect(0,0,side,side);c.imageSmoothingEnabled=false;c.scale(side/96,side/96);
 // Same camera box for every frame. Registration cancels atlas layout drift;
 // no per-frame zoom, whole-character rotation or generated extra props.
 const scale=80/(bottom-top),[dx,dy]=m.offsets[index],ox=48-(left+right)/2*scale,oy=90.24-bottom*scale;
 c.drawImage(atlases[s],index%3*m.cell,Math.floor(index/3)*m.cell,m.cell,m.cell,ox+dx*scale,oy+dy*scale,m.cell*scale,m.cell*scale);
 canvas.dataset.frame=String(index);canvas.dataset.state=s;
}
function time(now){return elapsed+(playing&&!reduced?(now-entered)/1000:0);}
function draw(now,force=false){if(!ready)return;const t=time(now);if(playing&&!reduced)frame=frameAt(state,t);const mini=cards.map(card=>playing&&!reduced?frameAt(card.state,t):frame);const key=[state,frame,...mini].join('/');if(!force&&key===lastKey)return;lastKey=key;
 drawSprite($('petCanvas'),state,frame);drawSprite($('detailCanvas'),state,frame);cards.forEach((card,i)=>drawSprite(card.element.querySelector('canvas'),card.state,mini[i]));$('frameCount').textContent=(frame+1)+' / 6';}
function loop(now){raf=null;draw(now);if(playing&&!reduced&&!document.hidden)raf=requestAnimationFrame(loop);}
function start(){if(raf!==null)cancelAnimationFrame(raf);raf=null;draw(performance.now(),true);if(ready&&playing&&!reduced&&!document.hidden)raf=requestAnimationFrame(loop);}
function freeze(){elapsed=time(performance.now());entered=performance.now();}
function select(s){state=s;elapsed=0;entered=performance.now();frame=0;refresh();start();}
function refresh(){
 $('sceneCaption').textContent=captions[state];$('status').textContent=reduced?'已减少动态 · 保留完整坐姿':playing?'正在播放 · '+captions[state]:'已暂停 · 可用箭头逐帧查看';
 $('bubble').innerHTML='Tomy · '+(state==='work'?'专注中':'休息中')+'<span>'+(state==='work'?'25:00':'05:00')+'</span>';
 $('modes').querySelectorAll('button').forEach(b=>b.classList.toggle('active',b.dataset.state===state));cards.forEach(card=>card.element.classList.toggle('active',card.state===state));clamp();
}
function clamp(){const w=pet.offsetWidth,h=pet.offsetHeight;if(!userMoved){x=stage.clientWidth-w-28;y=stage.clientHeight-h-26;}x=Math.max(14,Math.min(stage.clientWidth-w-14,x));y=Math.max(54,Math.min(stage.clientHeight-h-14,y));pet.style.left=x+'px';pet.style.top=y+'px';const bubble=$('bubble'),pad=bubble.offsetWidth/2+8;bubble.style.left=(Math.max(pad,Math.min(stage.clientWidth-pad,x+w/2))-x)+'px';}
function resize(size){height=size;pet.style.width=size*1.2+'px';pet.style.height=size*1.2+'px';$('footprint').textContent='角色 '+size+' pt';clamp();draw(performance.now(),true);}
function step(direction){freeze();playing=false;$('animate').checked=false;frame=(frame+direction+6)%6;refresh();start();}
$('previousFrame').addEventListener('click',()=>step(-1));$('nextFrame').addEventListener('click',()=>step(1));
$('sizes').addEventListener('click',e=>{const b=e.target.closest('[data-size]');if(!b)return;$('sizes').querySelectorAll('button').forEach(n=>n.classList.toggle('active',n===b));resize(Number(b.dataset.size));});
$('themes').addEventListener('click',e=>{const b=e.target.closest('[data-theme]');if(!b)return;$('themes').querySelectorAll('button').forEach(n=>n.classList.toggle('active',n===b));stage.classList.toggle('dark',b.dataset.theme==='dark');});
$('animate').addEventListener('change',e=>{freeze();playing=e.target.checked;refresh();start();});$('reduce').addEventListener('change',e=>{freeze();reduced=e.target.checked;refresh();start();});
function replay(){elapsed=0;entered=performance.now();frame=0;playing=true;$('animate').checked=true;refresh();start();}$('replay').addEventListener('click',replay);pet.addEventListener('dblclick',replay);
pet.addEventListener('pointerdown',e=>{if(e.button!==0)return;drag={id:e.pointerId,px:e.clientX,py:e.clientY,x,y};pet.setPointerCapture(e.pointerId);});
pet.addEventListener('pointermove',e=>{if(!drag)return;const dx=e.clientX-drag.px,dy=e.clientY-drag.py;if(Math.hypot(dx,dy)>3){userMoved=true;pet.classList.add('dragging');}x=drag.x+dx;y=drag.y+dy;clamp();});
function end(e){drag=null;pet.classList.remove('dragging');if(pet.hasPointerCapture(e.pointerId))pet.releasePointerCapture(e.pointerId);}pet.addEventListener('pointerup',end);pet.addEventListener('pointercancel',end);
pet.addEventListener('keydown',e=>{const d={ArrowLeft:[-8,0],ArrowRight:[8,0],ArrowUp:[0,-8],ArrowDown:[0,8]}[e.key];if(d){e.preventDefault();userMoved=true;x+=d[0];y+=d[1];clamp();}if(e.key==='Enter')replay();});
document.addEventListener('visibilitychange',()=>{if(document.hidden){freeze();if(raf!==null)cancelAnimationFrame(raf);raf=null;}else{entered=performance.now();start();}});new ResizeObserver(clamp).observe(stage);
try{
 const response=await fetch('assets/tomy-seated-motion-v1.json');if(!response.ok)throw Error('Missing motion metadata');metadata=await response.json();
 await Promise.all(states.map(async s=>{const image=new Image();image.src=metadata[s].file;await image.decode();if(image.width!==1536||image.height!==1024)throw Error('Unexpected sprite atlas dimensions');atlases[s]=image;}));
 ready=true;entered=performance.now();resize(height);refresh();start();
}catch(error){$('status').textContent='动作素材载入失败，请刷新预览。';console.error(error);}
