import net
import crypto.aes
import crypto.cipher
import rand
import crypto.sha256
import crypto.hmac

fn unpad_message(message []u8) []u8 {
    padding_size := int(message[message.len - 1])
    return message[..message.len - padding_size]
}

fn aes_cbc_de(mut src []u8, key []u8, iv []u8) {
    block := aes.new_cipher(key)
    mut mode := cipher.new_cbc(block, iv)
    mode.decrypt_blocks(mut src, src.clone())
}

fn authentication(mut sock net.TcpConn) bool {
    // Shared secret key
    secret_key := 'Agent-Alpha-7'

    // Send a challenge to the client
    challenge := rand.string(16)
    sock.write(challenge.bytes()) or {
        eprintln('Failed to write challenge to client: $err')
        return false
    }

    // Wait for the response
    mut response := []u8{len: sha256.size} 
    sock.read(mut response) or {
        eprintln('Failed to read response from client: $err')
        return false
    }

    // Calculate the expected response
    expected_response := hmac.new(secret_key.bytes(), challenge.bytes(), sha256.sum, sha256.block_size)

    // Check if the response matches the expected response
    if !hmac.equal(response, expected_response) {
        eprintln('Failed to authenticate client: invalid response')
        return false
    }

    // Client has been authenticated
    println('Client authenticated successfully')
    return true
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

        go handle_client(mut sock) 
    }
}

fn handle_client(mut sock net.TcpConn) {
    defer { sock.close() or {} }
    
    if !authentication(mut sock) {
        eprintln('Failed to authenticate client')
        return
    }

    mut key := []u8{len: 32}
    mut iv := []u8{len: 16}
    sock.read(mut key) or {
        eprintln('Failed to read key from client: $err')
        return
    }
    sock.read(mut iv) or {
        eprintln('Failed to read iv from client: $err')
        return
    }

    // Send the message "SCAN" to the client
    sock.write("SCAN".bytes()) or {
        eprintln('Failed to send message to client: $err')
        return
    }

    for {
        // Read the encrypted response from the client
        mut buf := []u8{len: 9082}
        num_bytes := sock.read(mut buf) or {
            eprintln('Failed to read from client: $err')
            break
        }

        // Decrypt and unpad
        aes_cbc_de(mut buf[..num_bytes], key, iv)
        decrypted_message := unpad_message(buf[..num_bytes])

        println(decrypted_message.bytestr())
    }
}
