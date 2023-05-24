import net

fn main() {
    listen_port := "0.0.0.0:8080"
    mut listener := net.listen_tcp(net.AddrFamily.ip, listen_port) or {
        eprintln('Failed to create listener: $err')
        return
    }

    println('Listening on port: $listen_port')
    for {
        mut sock := listener.accept() or {
            eprintln('Failed to accept connection: $err')
            continue
        }

        // Envoie le message "SCAN" au client
        sock.write("SCAN".bytes()) or {
            eprintln('Failed to send message to client: $err')
            continue
        }

        for {
            // Lit la réponse du client
            mut buf := []u8{len: 1024}
            num_bytes := sock.read(mut buf) or {
                eprintln('Failed to read from client: $err')
                break
            }

            message := buf[..num_bytes].str()
            println('Received output from client: $message')
        }

        sock.close() or {}
    }
}
