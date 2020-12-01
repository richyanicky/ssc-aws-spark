#!/usr/bin/env python3

import base64, os
import sys
from Crypto.Cipher import AES

'''
This script uses a "password" to encrypt a string "private_msg" (e.g. SSC credential).
It returns a string encrypted word
'''

def encrypt_message(private_msg, password, padding_character='}', AES_key_length=16):
    # convert from string to bytes
    password_bytes = bytes(password, 'utf-8')
    # pad the secret key to be 16x
    padded_password = password_bytes + (bytes(padding_character, 'utf-8') * ((AES_key_length-len(password_bytes)) % AES_key_length))
    # use the password to create a AES cipher
    cipher = AES.new(padded_password)
    # pad the private_msg - because AES encryption requires the length of the msg to be a multiple of 16
    padded_private_msg = private_msg + (padding_character * ((AES_key_length-len(private_msg)) % AES_key_length))
    # use the cipher to encrypt the padded message
    encrypted_msg = cipher.encrypt(padded_private_msg)
    # encode the encrypted msg for storing safely in the database
    encoded_encrypted_msg = base64.b64encode(encrypted_msg)
    # return encoded encrypted message - decode the bytes object to a string
    return encoded_encrypted_msg.decode("utf-8")



if __name__ == "__main__":
    password = sys.argv[1]
    private_msg = sys.argv[2]
    encoded_encrypted_msg = encrypt_message(private_msg, password)
    sys.stdout.write(encoded_encrypted_msg)
