#!/usr/bin/python3
import base64, os
import sys
from os import urandom
from Crypto.Cipher import AES

'''
This script uses a "password" to decrypt a string "private_msg" (e.g. SSC credential).
It returns a string word
'''

def decrypt_message(encoded_encrypted_msg, password, padding_character='}', AES_key_length=16):
    # decode the encoded encrypted message and encoded secret key
    encrypted_msg = base64.b64decode(bytes(encoded_encrypted_msg, 'utf-8'))
    # pad the secret key to be 16x
    password_bytes = bytes(password, 'utf-8')
    padded_password = password_bytes + (bytes(padding_character, 'utf-8') * ((AES_key_length-len(password_bytes)) % AES_key_length))
    # use the decoded secret key to create a AES cipher
    cipher = AES.new(padded_password)
    # use the cipher to decrypt the encrypted message
    padded_encrypted_msg = encrypted_msg + (bytes(padding_character, 'utf-8')  * ((AES_key_length-len(encrypted_msg)) % AES_key_length))
    decrypted_msg = cipher.decrypt(padded_encrypted_msg)
    # unpad the encrypted message
    unpadded_private_msg = decrypted_msg.decode("utf-8").rstrip(padding_character)
    # return a decrypted original private message
    return unpadded_private_msg



if __name__ == "__main__":
    password = sys.argv[1]
    encoded_encrypted_msg = sys.argv[2]
    decrypted_msg = decrypt_message(encoded_encrypted_msg, password)
    sys.stdout.write("%s\n"%(decrypted_msg))
