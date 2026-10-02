"""One bounded system DNS/TCP/TLS check per platform host; no alternate resolver or proxy."""
import json
from pathlib import Path
import socket
import ssl
import time

results=[]
for host in ['www.youtube.com','xhslink.cn','www.xiaohongshu.com']:
    item={'host':host,'proxy':'DIRECT','resolver':'system default'}
    started=time.monotonic()
    try:
        addresses=socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)
        item['dnsAddresses']=list(dict.fromkeys(record[4][0] for record in addresses))
        family,kind,protocol,_,address=addresses[0]
        with socket.socket(family,kind,protocol) as connection:
            connection.settimeout(6)
            item['phase']='TCP'
            connection.connect(address)
            item['tcp']='CONNECTED'
            item['phase']='TLS'
            with ssl.create_default_context().wrap_socket(connection,server_hostname=host) as secured:
                item['tls']=secured.version()
                item['certificateValidated']=True
                item['status']='CONNECTED; no HTTP request sent'
    except Exception as error:
        item.update(status='STOPPED',failure='networkFailure',errorType=type(error).__name__,
                    osError=getattr(error,'errno',None),winError=getattr(error,'winerror',None))
    item['elapsedMs']=round((time.monotonic()-started)*1000)
    results.append(item)
Path(__file__).resolve().with_name('windows-network-diagnostic.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(json.dumps(results,indent=2))
