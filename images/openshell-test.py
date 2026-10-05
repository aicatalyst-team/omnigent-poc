import socket

listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

try:
  listener.bind(("127.0.0.1", 0))  # Choose an available loopback port.
  listener.listen(1)

  client.connect(listener.getsockname())
  print("client connected")

  try:
      connection, peer = listener.accept()
      print(f"accept succeeded; peer={peer}")
      connection.close()
  except OSError as exc:
      print(f"accept failed: errno={exc.errno}, message={exc.strerror}")
finally:
  client.close()
  listener.close()

