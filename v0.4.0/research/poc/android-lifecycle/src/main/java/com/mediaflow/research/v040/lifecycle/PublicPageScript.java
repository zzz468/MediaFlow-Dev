package com.mediaflow.research.v040.lifecycle;

import org.json.JSONObject;

// Read-only document-start restriction guard and bounded named-hydration summary.
// Observe only the page's existing same-origin fetch responses. No extra request,
// replay, Cookie access or raw payload export; XHR/native subresources are not covered.
final class PublicPageScript {
    static JSONObject summary(JSONObject input,String target) {
        JSONObject out=new JSONObject();
        try{
            String raw=input.getString("payload");if(raw.length()>500000)throw new IllegalArgumentException("budget");
            JSONObject root;
            try{root=new JSONObject(raw);}catch(Exception e){root=new JSONObject(android.net.Uri.decode(raw));}
            JSONObject match=find(root,target,0,new int[]{0});
            org.json.JSONArray images=null;
            if(match!=null){JSONObject post=match.optJSONObject("image_post_info");if(post!=null)images=post.optJSONArray("images");if(images==null)images=match.optJSONArray("images");if(images==null)images=match.optJSONArray("images_v2");}
            java.util.Set<String> urls=new java.util.HashSet<>();
            if(images!=null)for(int i=0;i<images.length();i++){
                JSONObject image=images.optJSONObject(i);if(image==null)continue;
                JSONObject display=image.optJSONObject("display_image");org.json.JSONArray list=display==null?image.optJSONArray("url_list"):display.optJSONArray("url_list");
                if(list!=null)for(int j=0;j<list.length();j++){String u=list.optString(j);if(u.startsWith("https://")){urls.add(u);break;}}
            }
            out.put("operation",input.getString("operation"));out.put("root",input.getString("root"));out.put("targetMatch",match!=null);out.put("gallery",match!=null&&images!=null&&images.length()>0);
            out.put("imageCount",images==null?0:images.length());out.put("differentImageUrlCount",urls.size());out.put("titlePresent",match!=null&&!match.optString("desc").isEmpty());out.put("authorPresent",match!=null&&match.optJSONObject("author")!=null);
            out.put("decodeStatus",match!=null&&images!=null&&images.length()>0?"SUCCESS":"NO_MATCH");
        }catch(Exception e){try{out.put("decodeStatus","ERROR");}catch(Exception ignored){}}
        return out;
    }
    private static JSONObject find(Object value,String target,int depth,int[] budget){
        if(value==null||depth>16||budget[0]++>6000)return null;
        if(value instanceof JSONObject){JSONObject o=(JSONObject)value;if(target.equals(o.optString("aweme_id")))return o;java.util.Iterator<String> keys=o.keys();while(keys.hasNext()){JSONObject found=find(o.opt(keys.next()),target,depth+1,budget);if(found!=null)return found;}}
        else if(value instanceof org.json.JSONArray){org.json.JSONArray a=(org.json.JSONArray)value;for(int i=0;i<a.length();i++){JSONObject found=find(a.opt(i),target,depth+1,budget);if(found!=null)return found;}}
        return null;
    }
    static String source(String targetId,String operation) {
        return "const mfOperation="+JSONObject.quote(operation)+";"+"""
        (()=>{
          if(window!==window.top)return;
          let stopped=false;const delivered=new Set(),readers=new Set();
          const send=x=>{if(!stopped)MF040Public.postMessage(JSON.stringify({...x,operation:mfOperation}));};
          send({kind:'bridgeInitialized'});
          window.__mf040Ack=()=>send({kind:'bridgeAck'});
          const stop=()=>{stopped=true;observer.disconnect();for(const r of readers)r.cancel().catch(()=>{});readers.clear();};
          window.__mf040Stop=stop;
          const check=()=>{
            if(stopped)return true;
            const t=(document.body?.innerText||'').slice(0,20000),p=location.pathname;
            let reason='';
            if(/captcha|verify|challenge/i.test(p)||/验证码|人机验证|安全验证|滑块验证|完成验证/.test(t))reason='browserVerification';
            else if(/login|passport/i.test(p)||document.querySelector('input[type=password]')||/扫码登录|请先登录|登录后观看|登录后继续/.test(t))reason='loginRequired';
            else if(/地区限制|所在地区不可/.test(t))reason='regionRestricted';
            else if(/无权访问|权限不足|付费观看|购买后观看/.test(t))reason='accessRestricted';
            if(reason){send({kind:'restriction',reason});stop();return true;}
            return false;
          };
          const inspect=()=>{
            if(check())return;
            const names=['RENDER_DATA','_ROUTER_DATA','__UNIVERSAL_DATA_FOR_REHYDRATION__'];
            for(const root of names){
              if(delivered.has(root))continue;
              const el=document.getElementById(root);
              let data=el?.textContent;
              if(!data)continue;
              if(data.length>500000)continue;
              send({kind:'hydration',root,payload:data});
              delivered.add(root);
            }
            for(const el of document.querySelectorAll('script[type="application/json"],script[type="application/ld+json"]')){
              if(names.includes(el.id)||delivered.has(el))continue;
              const data=el.textContent;if(!data||data.length>500000)continue;
              send({kind:'jsonCandidate',root:'publicJsonScript',payload:data});delivered.add(el);
            }
          };
          const observer=new MutationObserver(()=>{if(!check())inspect();});
          observer.observe(document,{childList:true,subtree:true});
          const originalFetch=window.fetch;
          window.fetch=function(...args){
            const promise=Reflect.apply(originalFetch,this,args);
            promise.then(response=>{
              if(stopped||check())return;
              const u=new URL(response.url,location.href);
              if(u.origin!==location.origin)return;
              if(/captcha|verify|challenge|login|passport/i.test(u.pathname)){send({kind:'restriction',reason:'responseRestriction'});stop();return;}
              const mime=(response.headers.get('content-type')||'').split(';')[0].toLowerCase();
              send({kind:'responseMetadata',status:response.status,mime,source:'sameOriginFetch'});
              if(!/json|text\\/html|javascript/.test(mime)||Number(response.headers.get('content-length'))>500000)return;
              let reader;try{reader=response.clone().body?.getReader();}catch(_){return;}if(!reader)return;
              readers.add(reader);
              (async()=>{
                let size=0;const chunks=[];
                try{
                  while(!stopped){const part=await reader.read();if(stopped)return;if(part.done)break;size+=part.value.length;if(size>500000){await reader.cancel();return;}chunks.push(part.value);}
                  if(stopped||check())return;
                  const bytes=new Uint8Array(size);let at=0;for(const c of chunks){bytes.set(c,at);at+=c.length;}
                  send({kind:'responseBody',root:'sameOriginFetch',mime,payload:new TextDecoder().decode(bytes)});
                }catch(_){if(!stopped)send({kind:'bodyReadError'});}
                finally{readers.delete(reader);}
              })();
            }).catch(()=>{});
            return promise; // Preserve the page's original result/rejection; never fetch again.
          };
          document.addEventListener('DOMContentLoaded',()=>{send({kind:'documentReady'});inspect();},{once:true});
          inspect();
        })();
        """;
    }
}
