import net
import os
import crypto.aes
import crypto.cipher
import crypto.rand
import crypto.hmac
import crypto.sha256

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
    secret_key := 'Sightkey'

    server_addr := "127.0.0.1:8080"
    mut conn := net.dial_tcp(server_addr) or {
        eprintln('Failed to connect to server: $err')
        return
    }

    // Read the challenge from the server
    mut challenge := []u8{len: 16} // Adjust the length as per your challenge string
    conn.read(mut challenge) or {
        eprintln('Failed to read challenge from server: $err')
        return
    }

    println('Received challenge: ' + challenge.bytestr())

    // Respond to the challenge
    response := hmac.new(secret_key.bytes(), challenge, sha256.sum, sha256.block_size)
    conn.write(response) or {
        eprintln('Failed to write response to server: $err')
        return
    }

    // Send the key and IV to the server
    conn.write(key) or {
        eprintln('Failed to send key to server: $err')
        return
    }
    conn.write(iv) or {
        eprintln('Failed to send iv to server: $err')
        return
    }

    // Maintain connection with server
    keep_alive := true
    for keep_alive {
        // Read the server's message
        mut buf := []u8{len: 9082}
        num_bytes := conn.read(mut buf) or {
            eprintln('Failed to read from server: $err')
            break
        }

        message := (buf[..num_bytes]).bytestr().trim_space()

        if message == "SCAN" {
            // Execute the command "echo test" and get its output
            output := os.execute("cmd /c echo test")

            // Padding and encryption
            mut padded_message := pad_message(output.output.bytes())
            aes_cbc_en(mut padded_message, key, iv)

            // Send the encrypted output to the server
            conn.write(padded_message) or {
                eprintln('Failed to send output to server: $err')
                return
            }

        }
    }

    conn.close() or {}
}
