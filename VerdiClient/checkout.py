from __future__ import print_function
# checkout laser_slug checked_out client_slug private_key
#   All inputs are strings except for checked_out which is 0/1

import httplib, urllib, urllib2, hashlib
import os, sys
from Crypto.Cipher import PKCS1_OAEP
from Crypto.PublicKey import RSA

try:
    laser = sys.argv[1]
    checked_out = int(sys.argv[2])
    private_key = sys.argv[3]
except:
    raise Exception('Incorrect inputs.')

with open(private_key,'rb') as f:
    private_key = f.read()
key = RSA.importKey(private_key)
m = hashlib.sha256()
m.update(key.publickey().exportKey('PEM'))
pubkey = m.digest().encode('hex')
url = 'http://qplab-hwserver.mit.edu/autocheckout/%s/%i/%s/'%(laser,checked_out,pubkey)

# Send GET
content = urllib2.urlopen(url,timeout=2).read()
content = content.split('<br>')
if len(content)<2:
    raise Exception(content)
challenge = content[0]
serverpubkey = content[1]

# Decrypt challenge from server
cipher = PKCS1_OAEP.new(key)
challenge = cipher.decrypt(challenge.decode('hex'))

# Perform XOR with new random number
m = os.urandom(214)
out = "".join(chr(ord(x) ^ ord(y)) for x, y in zip(challenge, m))

# Encrypt message to server
key = RSA.importKey(serverpubkey)
cipher = PKCS1_OAEP.new(key)
out = cipher.encrypt(out)

# Send POST
values = {'challenge':out.encode('hex'),
          'm':m.encode('hex')}
data = urllib.urlencode(values)
req = urllib2.Request(url,data)
rsp = urllib2.urlopen(req)
content = rsp.read()
print(content)
