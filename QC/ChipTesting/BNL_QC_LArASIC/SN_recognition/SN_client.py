"""
SN_client.py — sends a directory of image files to server.py over TCP, and
waits for a response
 
Run:
    python SN_client.py --host SERVER_IP --port 5000 \
        --input ./my_files --output ./processed_files
"""
import argparse
import io
import socket
import tarfile
from pathlib import Path
 
HEADER_SIZE = 8
 
 
def recv_exact(conn: socket.socket, n: int) -> bytes:
    buf = bytearray()
    while len(buf) < n:
        chunk = conn.recv(min(65536, n - len(buf)))
        if not chunk:
            raise ConnectionError("Connection closed before all data was received")
        buf.extend(chunk)
    return bytes(buf)
 
 
def recv_payload(conn: socket.socket) -> bytes:
    length = int.from_bytes(recv_exact(conn, HEADER_SIZE), "big")
    return recv_exact(conn, length)
 
 
def send_payload(conn: socket.socket, data: bytes) -> None:
    conn.sendall(len(data).to_bytes(HEADER_SIZE, "big"))
    conn.sendall(data)
 
 
def dir_to_tar_bytes(directory: Path) -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for item in directory.iterdir():
            tar.add(item, arcname=item.name)
    return buf.getvalue()
 
 
def tar_bytes_to_dir(data: bytes, directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        tar.extractall(directory)
 
 
def send_directory_and_wait(host: str, port: int, input_dir: Path, output_dir: Path) -> None:
    if not input_dir.is_dir():
        raise NotADirectoryError(f"{input_dir} is not a directory")
 
    print(f"[client] packing {input_dir} ...")
    tar_data = dir_to_tar_bytes(input_dir)
 
    print(f"[client] connecting to {host}:{port} ...")
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((host, port))
 
        print(f"[client] sending {len(tar_data)} bytes...")
        send_payload(s, tar_data)
 
        print("[client] waiting for server to process files...")
        # recv_payload blocks here until the server has finished processing
        # and sent its response — this is the "wait" step.
        result_data = recv_payload(s)
 
    print(f"[client] received {len(result_data)} bytes, unpacking to {output_dir} ...")
    tar_bytes_to_dir(result_data, output_dir)
    print("[client] done")
 
 
def main():
    parser = argparse.ArgumentParser(description="File-processing client")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5000)
    parser.add_argument("--input", required=True, help="Directory of files to send")
    parser.add_argument("--output", required=True, help="Directory to write processed files to")
    args = parser.parse_args()
 
    send_directory_and_wait(args.host, args.port, Path(args.input), Path(args.output))
 
    # Execution only reaches here after the processed files have arrived.
    print("[client] processed files are ready — continuing with the rest of the program.")
 
 
if __name__ == "__main__":
    main()