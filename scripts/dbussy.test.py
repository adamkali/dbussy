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
    col_defs = []

    try:
        sock.connect(server_address)
        for each in message1:
            if each["cmd"] == "selectTop100":
                print(each)
                if col_defs:
                    each["col_defs"] = col_defs
                print(each)
                sock.sendall(json.dumps(each).encode())
                response = sock.recv(1024)
                json_connect = json.loads(response.decode())
                print(json.dumps(json_connect, indent=4))
            elif each["cmd"] == "connect":
                sock.sendall(json.dumps(each).encode())
                response = sock.recv(1024)
                json_connect = json.loads(response.decode())
                for fach in json_connect["response"]:
                    for gach in fach.get("schema"):
                        col_defs.append({"col_name": gach.get("col_name"), "col_type":gach.get("col_type")})
                print(json.dumps(json_connect, indent=4))
            else:
                sock.sendall(json.dumps(each).encode())
                response = sock.recv(1024)
                print(json.dumps(json.loads(response.decode()), indent=4))
    finally:
        print("Closing connection")
        sock.close()
if __name__ == "__main__":
    main()

