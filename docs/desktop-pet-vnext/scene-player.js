const $ = id => document.getElementById(id);
const states = ['idle','work','rest','workPaused','restPaused','workFinished','restFinished'];
const labels = ['准备中','专注中','休息中','专注暂停','休息暂停','专注达成','休息结束'];
const captions = ['安静陪伴，轻轻呼吸。','抱着书阅读，偶尔点头翻一页。','靠着小枕头睡一会儿。','合上书，等你回来继续。','从枕头上醒来，暂停休息。','轻轻跃起，收下一颗星星。','睡醒伸个懒腰，准备下一轮。'];
const sheet = new Image(), props = new Image();
sheet.src = 'assets/tomy-blink-strip.png'; props.src = 'assets/tomy-scene-props-v1.png';
const eyes = [[150,335,85,88],[341,364,85,89]];
const crops = [[30,110,480,340],[30,110,480,340],[51,190,424,283],[37,118,468,269],[120,83,269,332],[111,93,271,299]];
const stage = $('desktop'), pet = $('pet');
let state='work', entered=performance.now(), started=entered, transition=null, ready=false;
let playing=true, reduced=matchMedia('(prefers-reduced-motion:reduce)').matches, height=80, x=0,y=0,userMoved=false,drag=null,hovered=false,raf=null;
$('reduce').checked=reduced;
const mini=[];
states.forEach((s,i)=>{
 const b=document.createElement('button');b.textContent=labels[i];b.dataset.state=s;b.addEventListener('click',()=>select(s));$('modes').append(b);
 const card=document.createElement('button');card.setAttribute('aria-label',labels[i]+'场景');card.innerHTML='<canvas width="288" height="288"></canvas><span>'+labels[i]+'</span>';card.addEventListener('click',()=>select(s));$('overview').append(card);mini.push(card);
});
function blink(t,cycle=10){t%=cycle;for(const start of [1.25,cycle*.555,cycle*.81]){const d=t-start;if(d>=0&&d<.08)return 1;if(d>=.08&&d<.15)return 2;if(d>=.15&&d<.23)return 1;}return 0;}
function pose(s,t,dynamic){
 const p={eyes:0,x:0,y:0,sx:1,sy:1,angle:0,page:false};const breath=dynamic?Math.sin(t*Math.PI*2/4.7):0;
 switch(s){
 case 'idle':p.eyes=dynamic?blink(t):0;p.sx-=breath*.0025;p.sy+=breath*.005;p.angle=dynamic?Math.sin(t*Math.PI*2/9.7)*.7:0;break;
 case 'work':p.angle=-4;p.eyes=dynamic?blink(t):0;p.sy=.96+breath*.004;{const n=t%6.4;if(dynamic&&n>3.5&&n<4.4)p.angle-=Math.sin((n-3.5)/.9*Math.PI)*3;p.page=dynamic&&n>3.55&&n<4.15;}break;
 case 'workPaused':p.sy=.98;break;
 case 'rest':p.eyes=2;p.x=-18;p.y=-5;p.angle=24;p.sx=.85;p.sy=.85+(dynamic?Math.sin(t*Math.PI*2/5.8)*.012:0);break;
 case 'restPaused':p.x=-11;p.y=-4;p.angle=12;p.sx=.9;p.sy=.9;break;
 case 'workFinished':if(dynamic&&t>.25&&t<1.65){const z=(t-.25)/1.4,l=Math.sin(z*Math.PI)**2;p.y=-8*l;p.sx+=l*.016;p.sy+=l*.018;p.angle=Math.sin(z*Math.PI*2)*2.5;}break;
 case 'restFinished':p.x=-6;p.sx=.92;p.sy=.98;if(dynamic&&t>.15&&t<1.65){const z=Math.sin((t-.15)/1.5*Math.PI);p.sx-=z*.03;p.sy+=z*.065;}break;
 }
 return p;
}
function layers(s,page){switch(s){
 case 'work':return [[page?1:0,19,55,58,34,true]];
 case 'workPaused':return [[2,26,67,44,25,true]];
 case 'rest':case 'restPaused':return [[3,24,73,68,19,false]];
 case 'workFinished':return [[4,34,62,26,32,true]];
 case 'restFinished':return [[3,29,77,62,15,false],[5,73,13,17,19,false]];
 default:return [];
}}
function bodyTransform(c,p){c.translate(48+p.x,90.24+p.y);c.rotate(p.angle*Math.PI/180);c.scale(p.sx,p.sy);c.translate(-48,-90.24);}
function render(canvas,p,s,previous=null,mix=1){
 const c=canvas.getContext('2d'),side=canvas.width;c.setTransform(1,0,0,1,0,0);c.clearRect(0,0,side,side);c.imageSmoothingEnabled=false;c.scale(side/96,side/96);
 const scale=80/597,ox=(96-724*scale)/2,oy=90.24-671*scale;
 c.save();bodyTransform(c,p);c.drawImage(sheet,0,0,724,724,ox,oy,724*scale,724*scale);
 if(p.eyes)for(const [ex,ey,w,h] of eyes)c.drawImage(sheet,p.eyes*724+ex,ey,w,h,ox+ex*scale,oy+ey*scale,w*scale,h*scale);c.restore();
 function drawProps(s,alpha){if(!s||alpha<=0)return;for(const [i,x,y,w,h,attached] of layers(s,p.page)){c.save();c.globalAlpha=alpha;if(attached)bodyTransform(c,p);const [cx,cy,cw,ch]=crops[i];c.drawImage(props,(i%3)*512+cx,Math.floor(i/3)*512+cy,cw,ch,x,y,w,h);c.restore();}}
 drawProps(previous,1-mix);drawProps(s,mix);
}
function current(now){const t=Math.max(0,(now-entered)/1000),dynamic=playing&&!reduced;let p=pose(state,t,dynamic),mix=1;
 if(transition&&dynamic){mix=Math.min(1,(now-transition.at)/340);mix=mix*mix*(3-2*mix);for(const k of ['x','y','sx','sy','angle'])p[k]=transition.pose[k]+(p[k]-transition.pose[k])*mix;p.eyes=Math.round(transition.pose.eyes+(p.eyes-transition.pose.eyes)*mix);}
 if(hovered&&state==='rest')p.eyes=1;
 return {p,mix};
}
function draw(now){if(!ready)return;const {p,mix}=current(now);render($('petCanvas'),p,state,transition?.state,mix);render($('detailCanvas'),p,state,transition?.state,mix);const t=(now-started)/1000;mini.forEach((card,i)=>render(card.querySelector('canvas'),pose(states[i],states[i].endsWith('Finished')?3:t,playing&&!reduced),states[i]));}
function loop(now){raf=null;draw(now);if(playing&&!reduced&&!document.hidden)raf=requestAnimationFrame(loop);}
function start(){if(raf!==null)cancelAnimationFrame(raf);raf=null;draw(performance.now());if(ready&&playing&&!reduced&&!document.hidden)raf=requestAnimationFrame(loop);}
function select(s){const now=performance.now();transition={pose:current(now).p,state,at:now};state=s;entered=now;refreshLabels();start();}
function refreshLabels(){const i=states.indexOf(state);$('sceneCaption').textContent=captions[i];$('bubble').innerHTML='Tomy · '+labels[i]+'<span>'+(['work','workPaused'].includes(state)?'25:00':['rest','restPaused'].includes(state)?'05:00':'')+'</span>';$('status').textContent=reduced?'已减少动态 · 保留各场景姿态':captions[i];document.querySelectorAll('#modes button').forEach(b=>b.classList.toggle('active',b.dataset.state===state));mini.forEach((b,j)=>b.classList.toggle('active',i===j));}
function clamp(){const w=pet.offsetWidth,h=pet.offsetHeight;if(!userMoved){x=stage.clientWidth-w-28;y=stage.clientHeight-h-26;}x=Math.max(14,Math.min(stage.clientWidth-w-14,x));y=Math.max(54,Math.min(stage.clientHeight-h-14,y));pet.style.left=x+'px';pet.style.top=y+'px';const bubble=$('bubble'),pad=bubble.offsetWidth/2+8;bubble.style.left=(Math.max(pad,Math.min(stage.clientWidth-pad,x+w/2))-x)+'px';}
function resize(size){height=size;pet.style.width=size*1.2+'px';pet.style.height=size*1.2+'px';$('footprint').textContent='角色 '+size+' pt';clamp();draw(performance.now());}
Promise.all([sheet.decode(),props.decode()]).then(()=>{if(sheet.width!==2172||sheet.height!==724||props.width!==1536||props.height!==1024)throw Error('Unexpected atlas dimensions');ready=true;resize(height);refreshLabels();start();}).catch(()=>{$('status').textContent='场景素材载入失败，请刷新预览。';});
$('sizes').addEventListener('click',e=>{const b=e.target.closest('[data-size]');if(!b)return;$('sizes').querySelectorAll('button').forEach(n=>n.classList.toggle('active',n===b));resize(Number(b.dataset.size));});
$('themes').addEventListener('click',e=>{const b=e.target.closest('[data-theme]');if(!b)return;$('themes').querySelectorAll('button').forEach(n=>n.classList.toggle('active',n===b));stage.classList.toggle('dark',b.dataset.theme==='dark');});
$('animate').addEventListener('change',e=>{playing=e.target.checked;refreshLabels();start();});$('reduce').addEventListener('change',e=>{reduced=e.target.checked;refreshLabels();start();});
function replay(){entered=performance.now();transition=null;start();} $('replay').addEventListener('click',replay);pet.addEventListener('dblclick',replay);
pet.addEventListener('pointerenter',()=>{hovered=true;draw(performance.now());});pet.addEventListener('pointerleave',()=>{hovered=false;draw(performance.now());});
pet.addEventListener('pointerdown',e=>{if(e.button!==0)return;drag={id:e.pointerId,px:e.clientX,py:e.clientY,x,y};pet.setPointerCapture(e.pointerId);});
pet.addEventListener('pointermove',e=>{if(!drag)return;const dx=e.clientX-drag.px,dy=e.clientY-drag.py;if(Math.hypot(dx,dy)>3){userMoved=true;pet.classList.add('dragging');}x=drag.x+dx;y=drag.y+dy;clamp();});
function end(e){drag=null;pet.classList.remove('dragging');if(pet.hasPointerCapture(e.pointerId))pet.releasePointerCapture(e.pointerId);}pet.addEventListener('pointerup',end);pet.addEventListener('pointercancel',end);
pet.addEventListener('keydown',e=>{const d={ArrowLeft:[-8,0],ArrowRight:[8,0],ArrowUp:[0,-8],ArrowDown:[0,8]}[e.key];if(d){e.preventDefault();userMoved=true;x+=d[0];y+=d[1];clamp();}if(e.key==='Enter')replay();});
document.addEventListener('visibilitychange',start);new ResizeObserver(clamp).observe(stage);
window.tomyPreview={getState:()=>({ready,playing,reduced,height,state,slot:pet.offsetWidth,pose:current(performance.now()).p})};
