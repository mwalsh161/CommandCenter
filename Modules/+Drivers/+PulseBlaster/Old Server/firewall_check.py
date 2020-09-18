from subprocess import check_output
from subprocess import CalledProcessError
import os

def test_rule(name = 'pythonservice.exe'):
    inbound = False
    outbound= False
    restricted = False

    # Determine firewall profile, and see if rule exists for pythonservice.exe
    out = check_output(['netsh','advfirewall','show','currentprofile'],shell=True)
    out = out.strip().split(os.linesep)
    if 'ON' not in out[2]: # No firewall
        raise Exception('No firewall detected!')

    # Check policy to see if inbound/outbound default
    if 'AllowInbound' in out[3]:
        inbound = True
    if 'AllowOutbound' in out[3]:
        outbound = True
    profile = out[0].split(' ')[0]

    try:
        out = check_output(['netsh','advfirewall','firewall','show','rule','name=%s'%name],shell=True)
    except CalledProcessError as err:
        if 'No rules match the specified criteria' in err.output:
            return inbound,outbound,restricted
        raise err
    # Parse Rules
    rules = []
    lines = out.split(os.linesep)
    i = 0
    current_rule = None
    while i < len(lines):
        if not lines[i]:
            i += 1
            continue
        if "Rule Name:" in lines[i]:
            rules.append(current_rule)
            current_rule = {}
            i += 2  # Skip dash line
            continue
        if "Ok." in lines[i]:
            rules.append(current_rule)
            break
        assert current_rule != None, Exception("No current_rule found!")
        temp = lines[i].split(':')
        assert len(temp) == 2, Exception("Not a single key: value pair:\n%s"%lines[i])
        [key,val] = temp
        current_rule[key] = val.strip()
        i += 1
    rules.pop(0)

    # Search rules
    for rule in rules:
        if rule['Enabled']=='Yes' and \
                rule['Action']=='Allow' and \
                rule['Protocol']=='TCP' and \
                profile in rule['Profiles']:
            if rule['Direction']=='In':
                inbound = True
            elif rule['Direction']=='Out':
                outbound = True
            if rule['RemotePort']!='Any' or \
                    rule['LocalPort']!='Any' or \
                    rule['RemoteIP']!='Any' or \
                    rule['LocalIP']!='Any':
                restricted = True
    return inbound,outbound,restricted

if __name__=='__main__':
    print test_rule('python')