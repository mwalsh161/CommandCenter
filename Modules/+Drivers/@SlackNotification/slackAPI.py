import json, requests, sys, base64

# Input to this function:
#   arg1: slack incoming webhook URL
#   arg2: json formatted payload to be sent to URL as base64 string
#
# NOTE: Upon an error, stdout will have text. No actual exception raised.
#   (Rationale simply that this code is simple enough to not require a traceback
#    and makes parsing in MATLAB cleaner)

def send(url,payload):
    #print(payload)
    #payload = payload.replace('%','&amp;').replace('<','&lt;').replace('>','&gt;')
    r = requests.post(url,data=payload,headers={'Content-Type':'application/json'})
    if r.status_code != 200:
        #payload = payload.replace('%','&amp;').replace('<','&lt;').replace('>','&gt;')
        pretty = json.dumps(json.loads(payload),indent=4) # json expects double quotes to load
        print('Request to slack returned an error %s:\n  %s\nPayload:\n%s'%(r.status_code,r.text,pretty))

if __name__ == '__main__':
    try:
        url = sys.argv[1]
        json_payload = base64.b64decode(sys.argv[2])
    except:
        raise Exception('Incorrect inputs.')
    send(url,json_payload)