import socket
import json

def main():
    server_address = ('127.0.0.1', 8987)
    message1 = []
    with open("test_data/test_3.json") as f:
        strng =  f.read()
        message1 = json.loads(strng)

    # Create a TCP/IP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    try:
        sock.connect(server_address)
        for each in message1:
            print(each)
            print("")
            sock.sendall(json.dumps(each).encode())
            response = sock.recv(1024)
            print(f"Received: {response.decode()}")
    finally:
        print("Closing connection")
        sock.close()
if __name__ == "__main__":
    main()

