# Intercept Password Fill and AutoFill hooks.

I am a security researcher who has developed a password vault using Threshold encryption. This
allows true end to end encryption of the contents of the password vault and the ability to
disable access to the vault from a device that is lost or compromised.

An open specification has been submitted to the IETF as an 
[Internet Draft](https://www.ietf.org/archive/id/draft-hallambaker-mesh-architecture-19.html).
This was discuissed at a BOF at the Singapore IETF, the last before the pandemic slowed 
everything down.

The key advantage to the password vault maintainer in this scheme is that they do not have any
access to the encrypted password data. It is all encrypted using AES-256 OCB under standard 
X448 ElGamal encryption. The threshold scheme only changes the decryption process, thus the
encryption is provably as secure as ordinary X448 key exchange. Thus the liability of the 
service provider is substantially less than under existing schemes where an aggrieved 
customer need not even suffer an injury to file a lawsuit, they merely need to imagine that
the service provider might have leaked the password data.

The Mathematical Mesh is designed to allow end users to make use of public key cryptography
with the same ease and transparency as TLS. Every device the user connects to their personal
Mesh has access to their shared data as if they were all a single machine.

The goal here is to kill passwords with a three step strategy:

Step 0: is to demonstrate the capability in at least one browser and show the UI is viable.

Step 1: is to get the open specification adopted by a sufficient group of browser providers to
support every platform.

Step 2: At this point it is practical for the user to use long and strong machine generated 
passwords with 120 bit work factors or better because they never have to remember them
or type them in.

Step 3: Every device that connects to the password vault is authenticating with public
key authentication and can just as easily use that to authenticate to the site. As the 
constituency of users with the Mesh password vault expands, it becomes attractive to replace
password auth with public key based schemes (TLS server auth, SAML, etc. etc.)

Lowering the security sensitivity of the service is critical as it allows the user to 
choose the service they trust which is in most cases not going to be a party with the
technical sophistication of a Microsoft, Google, Apple or so on. But the key thing in the
Mesh is that every user is their own ultimate source of trust. They don't give their 
enclair passwords to anyone.


## Hooks requested

I would ideally want to be able to override the password manager and form autofill managers
built into Edge/Chrome with my own schemes using information from threshold secured 

I can write my own code to grovel through the DOM but that is going to take me quite
a while to figure out.



