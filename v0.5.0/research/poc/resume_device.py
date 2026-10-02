"""Capture only necessary Android network facts and the independent research UI."""
import json,re,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parent
ADB=r'D:\Android\Sdk\platform-tools\adb.exe'
def adb(*args):
    return subprocess.run([ADB,*args],capture_output=True,timeout=20).stdout.decode('utf-8',errors='replace')
network=adb('shell','dumpsys','connectivity')
active=re.search(r'Active default network:\s*(\d+)',network)
agents=re.findall(r'NetworkAgentInfo\{network\{.*?(?=\n  NetworkAgentInfo|\Z)',network,re.S)
facts={'activeDefaultNetwork':active.group(1) if active else None,'privateDnsMode':adb('shell','settings','get','global','private_dns_mode').strip(),'privateDnsSpecifier':adb('shell','settings','get','global','private_dns_specifier').strip(),'httpProxy':adb('shell','settings','get','global','http_proxy').strip(),'ssidAndMacNotStored':True}
for agent in agents:
    if active and agent.startswith('NetworkAgentInfo{network{'+active.group(1)+'}'):
        facts['transport']='WIFI' if 'Transports: WIFI' in agent else 'VPN' if 'Transports: VPN' in agent else 'OTHER'
        facts['interface']=re.search(r'InterfaceName:\s*(\S+)',agent).group(1)
        dns=re.search(r'DnsAddresses:\s*\[([^]]*)\]',agent)
        facts['dns']=dns.group(1).strip() if dns else None
facts['vpnInterfacePresent']='vgate0' in adb('shell','ip','addr')
facts['vpnRoutingScope']='NOT VERIFIED; interface alone does not prove research app uses it'
(ROOT/'android-network-environment-resume.json').write_text(json.dumps(facts,indent=2),encoding='utf-8')
ui=adb('shell','cat','/data/local/tmp/mediaflow-v050-ui.xml')
own=[]
try:
    for node in ET.fromstring(ui).iter('node'):
        if node.get('package')=='com.mediaflow.research.v050.feasibility':
            own.append({k:node.get(k) for k in ['text','content-desc','bounds','clickable','enabled']})
except ET.ParseError: pass
print(json.dumps({'network':facts,'researchUi':own},ensure_ascii=True))
