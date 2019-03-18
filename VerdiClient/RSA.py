from __future__ import print_function
HELP = '''
RSA.py function_substring path_to_key/fname [data]
Functions:
  generate_key -> True: 2048 bit public and private key
  encrypt -> ciphertext as hex string: encrypts using key
  decrypt -> plaintext as hex string: decrypts using key
Path/fname
  for key generation, specify "base name". Code will append private.pem and public.pem
  for encrypt/decrypt, path to key
data
  should be hex string representation

Hex String:
If the ascii string is 'paul', the hex string should be '7061756c'
'''
from Crypto.Cipher import PKCS1_OAEP
from Crypto.PublicKey import RSA
from Crypto import Random
import sys, os

# Generate key
def generate_key(fname):
    fname = os.path.split(fname)[1]
    fname = os.path.splitext(fname)[0]
    random_generator = Random.new().read
    key = RSA.generate(2048,random_generator)
    with open(fname+'private.pem','wb') as f:
        f.write(key.exportKey('PEM'))
    with open(fname+'public.pem','wb') as f:
        f.write(key.publickey().exportKey('PEM'))
    return True

# Encrypt
def encrypt(key_path,data):
    # Data is hex. Example
    # If data says 'paul' in ascii, the input to the function should be '7061756c'
    with open(key_path,'rb') as f:
        key = RSA.importKey(f.read())
    data = data.decode('hex')
    cipher = PKCS1_OAEP.new(key)
    ciphertext = cipher.encrypt(data)
    return "".join("{:02x}".format(ord(c)) for c in ciphertext)

# Decrypt
def decrypt(key_path,data):
    # Data is hex. Example
    # If data says 'paul' in ascii, the input to the function should be '7061756c'
    with open(key_path,'rb') as f:
        key = RSA.importKey(f.read())
    data = data.decode('hex')
    cipher = PKCS1_OAEP.new(key)
    plaintext = cipher.decrypt(data)
    return plaintext

if __name__=='__main__':
#    for i in range(250):
#        print(i)
#        encrypt('public_key.pem',i*'a'.encode('hex'))
    args = sys.argv[1:]
    if len(args) < 1:
        print(HELP)
    elif args[0] in 'generate_key':
        if len(args)!=2:
            print(HELP)
        print(generate_key(args[1]))
    elif args[0] == 'encrypt':
        if len(args)!=3:
            print(HELP)
        print(encrypt(args[1],args[2]))
    elif args[0] == 'decrypt':
        if len(args)!=3:
            print(HELP)
        print(len(args[2][1:-1]))
        print(decrypt(args[1],args[2]))
    else:
        print(HELP)
