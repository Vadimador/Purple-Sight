import net
import os

fn main() {
    server_addr := "127.0.0.1:8080"
    mut conn := net.dial_tcp(server_addr) or {
        eprintln('Failed to connect to server: $err')
        return
    }

    for {
        // Lit le message du serveur
        mut buf := []u8{len: 1024}
        num_bytes := conn.read(mut buf) or {
            eprintln('Failed to read from server: $err')
            break
        }

        message := (buf[..num_bytes]).str().trim_space()
        println (buf)
        println (num_bytes)
        println (message)

        if message == "SCAN"{
            // Exécute la commande "echo test" et récupère son output
            output := os.execute("cmd /c echo test")
            println ("Sortie commande :" + output.output)

            // Envoie l'output au serveur
            conn.write_string(output.output) or {
                eprintln('Failed to send output to server: $err')
                return
            }
        }
    }

    conn.close() or {}
}
