import net
import crypto.aes
import crypto.cipher
import encoding.base64

fn unpad_message(message []u8) []u8 {
    padding_size := int(message[message.len - 1])
    return message[..message.len - padding_size]
}

fn aes_cbc_de(mut src []u8, key []u8, iv []u8) {
    block := aes.new_cipher(key)
    mut mode := cipher.new_cbc(block, iv)
    mode.decrypt_blocks(mut src, src.clone())
}

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

        mut key := []u8{len: 32}
        mut iv := []u8{len: 16}
        sock.read(mut key) or {
            eprintln('Failed to read key from client: $err')
            break
        }
        sock.read(mut iv) or {
            eprintln('Failed to read iv from client: $err')
            break
        }


        // Envoie le message "SCAN" au client
        sock.write("SCAN".bytes()) or {
            eprintln('Failed to send message to client: $err')
            continue
        }

        for {
            // Lit la réponse chiffrée du client
            mut buf := []u8{len: 1024}
            num_bytes := sock.read(mut buf) or {
                eprintln('Failed to read from client: $err')
                break
            }
            //println("Message chiffré reçu du client: $buf")

            // Déchiffrement et unpadding
            aes_cbc_de(mut buf[..num_bytes], key, iv)
            decrypted_message := unpad_message(buf[..num_bytes])

            println(decrypted_message.bytestr())
            //println(base64.decode(decrypted_message.bytestr()))
        }

        sock.close() or {}
    }
}
