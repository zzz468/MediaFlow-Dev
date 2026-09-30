// Fixed read-only research projection. Never return raw roots or credentials.
(()=>{
 const text=(document.body?.innerText||'').slice(0,20000);
 let stop='';
 if(document.querySelector('input[type=password]')||/扫码登录|请先登录|登录后观看|登录后继续/.test(text))stop='loginRequired';
 else if(/验证码|完成验证|安全验证/.test(text))stop='browserVerification';
 else if(/所在地区不可|地区限制/.test(text))stop='regionRestricted';
 else if(/无权访问|权限不足|付费观看|购买后观看/.test(text))stop='accessRestricted';
 if(stop)return {stop};
 const id='__TARGET_ID__',roots=[],works=[];
 let visits=0,urlBudget=128;
 function urls(v,depth=0){
  if(!v||depth>6)return [];
  if(Array.isArray(v))return v.slice(0,100).flatMap(x=>urls(x,depth+1));
  if(typeof v!=='object')return [];
  const a=[];
  for(const [k,x] of Object.entries(v)){
   if(['url_list','download_url_list'].includes(k)&&Array.isArray(x)){
    for(const u of x.slice(0,8))if(urlBudget>0&&typeof u==='string'&&u.length<4096&&/^https:\/\//.test(u)){a.push(u);urlBudget--;}
   }
   else if(['display_image','download_image','origin_image'].includes(k))a.push(...urls(x,depth+1));
  }return [...new Set(a)].slice(0,8);
 }
 function walk(v,depth=0){
  if(!v||typeof v!=='object'||depth>18||++visits>12000)return;
  const match=['aweme_id','item_id','itemId','awemeId'].some(k=>v[k]===id);
  if(match&&works.length<8){
   const fields=['image_post_info','images','images_v2','slides','gallery'].filter(k=>Object.hasOwn(v,k));
   const source=Array.isArray(v.image_post_info?.images)?v.image_post_info.images:
    Array.isArray(v.image_post_info?.image_list)?v.image_post_info.image_list:
    Array.isArray(v.images)?v.images:Array.isArray(v.images_v2)?v.images_v2:[];
   const images=source.slice(0,100).map(x=>({url_list:urls(x)}));
   works.push({aweme_id:id,aweme_type:typeof v.aweme_type==='number'?v.aweme_type:null,fields,images});
  }
  for(const x of Object.values(v))walk(x,depth+1);
 }
 function consume(name,value){
  if(value==null)return;
  let parsed=value,chars=null;
  if(typeof value==='string'){
   chars=value.length;if(chars>1048576){roots.push({name,chars,parsed:false,overBudget:true});return;}
   try{parsed=JSON.parse(value);}catch{try{parsed=JSON.parse(decodeURIComponent(value));}catch{roots.push({name,chars,parsed:false});return;}}
  }
  roots.push({name,chars,parsed:true});walk(parsed);
 }
 for(const name of ['RENDER_DATA','_ROUTER_DATA','__UNIVERSAL_DATA_FOR_REHYDRATION__']){
  const element=document.getElementById(name);if(element)consume('script:'+name,element.textContent);
  const d=Object.getOwnPropertyDescriptor(window,name);if(d&&'value'in d)consume('window:'+name,d.value);
 }
 [...document.querySelectorAll('script[type="application/json"],script[type="application/ld+json"]')].slice(0,8).forEach((s,i)=>consume('json-script:'+i,s.textContent));
 return {stop:'',roots,works,visits,documentReady:document.readyState};
})()
