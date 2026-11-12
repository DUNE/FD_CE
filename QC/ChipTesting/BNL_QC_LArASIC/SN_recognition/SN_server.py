"""
SN_server.py — receives a directory tar stream of chip images for SN extraction
before sending back the summary
 
Protocol (simple length-prefixed framing over a single TCP connection):
    client -> server: 8-byte big-endian length, then that many bytes of tar data
    server -> client: 8-byte big-endian length, then that many bytes of tar data
    connection closes after the reply is sent.
 
Run:
    python server.py --host 0.0.0.0 --port 5000
"""
 
import argparse
import io
import socket
import tarfile
import tempfile
from pathlib import Path
from SN_Class import SN_Class
 
HEADER_SIZE = 8  # bytes used to encode the payload length
 
 
def recv_exact(conn: socket.socket, n: int) -> bytes:
    """Read exactly n bytes from the socket (handles partial reads)."""
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
 
 
def process_files(sn_class: SN_Class, rootdir: Path) -> None:
    """
    Placeholder processing step — replace this with whatever the server
    actually needs to do to each incoming file.
 
    Right now it just copies each file and prepends "processed_" to the
    name, plus appends a line to text files, so the round trip is visible.
    """
    chip_ocr = sn_class.chip_ocr(rootdir)

    #output_dir.mkdir(parents=True, exist_ok=True)
    # for item in input_dir.iterdir():
    #     if item.is_file():
    #         dest = output_dir / f"processed_{item.name}"
    #         data = item.read_bytes()
    #         try:
    #             text = data.decode("utf-8")
    #             text += "\n# processed by server\n"
    #             dest.write_text(text)
    #         except UnicodeDecodeError:
    #             # binary file — just copy it through unchanged
    #             dest.write_bytes(data)
 
 
def handle_client(conn: socket.socket, addr) -> None:
    print(f"[server] connection from {addr}")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        incoming_dir = tmp_path / "incoming"
        outgoing_dir = tmp_path / "outgoing"
 
        print("[server] receiving files...")
        tar_data = recv_payload(conn)
        tar_bytes_to_dir(tar_data, incoming_dir)
        print(f"[server] received {len(list(incoming_dir.iterdir()))} file(s)")
 
        print("[server] processing files...")
        process_files(incoming_dir, outgoing_dir)
 
        print("[server] sending processed files back...")
        result_tar = dir_to_tar_bytes(outgoing_dir)
        send_payload(conn, result_tar)
        print("[server] done, closing connection")
 
 
def main():
    parser = argparse.ArgumentParser(description="File-processing server")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=5000)
    args = parser.parse_args()
 
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((args.host, args.port))
        s.listen(1)
        print(f"[server] listening on {args.host}:{args.port}")
        while True:
            conn, addr = s.accept()
            with conn:
                try:
                    handle_client(conn, addr)
                except Exception as e:
                    print(f"[server] error handling {addr}: {e}")
 
 
if __name__ == "__main__":
    main()