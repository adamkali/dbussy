import socket

def main():
    server_address = ('127.0.0.1', 8987)
    message1 =""
    message2 =""
    with open("test_data/test_1.json") as f:
        message1 = f.read()
    with open("test_data/test_2.json") as f:
        message2 = f.read()

    # Create a TCP/IP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    try:
        sock.connect(server_address)
        sock.sendall(message1.encode())
        response = sock.recv(1024)
        print(f"Received: {response.decode()}")
        sock.sendall(message2.encode())
        response = sock.recv(1024)
        print(f"Received: {response.decode()}")
    finally:
        print("Closing connection")
        sock.close()

if __name__ == "__main__":
    main()

