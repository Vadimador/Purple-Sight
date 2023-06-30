import net
import crypto.aes
import crypto.cipher
import os

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

fn unpad_message(message []u8) []u8 {
    padding_size := int(message[message.len - 1])
    return message[..message.len - padding_size]
}

fn aes_cbc_en(mut src []u8, key []u8, iv []u8) {
    block := aes.new_cipher(key)
    mut mode := cipher.new_cbc(block, iv)
    mode.encrypt_blocks(mut src, src.clone())
}

fn aes_cbc_de(mut src []u8, key []u8, iv []u8) {
    block := aes.new_cipher(key)
    mut mode := cipher.new_cbc(block, iv)
    mode.decrypt_blocks(mut src, src.clone())
}

fn read_encrypt_message(mut response &string, key []u8, iv []u8, mut sock net.TcpConn) bool {
 	mut buf := []u8{len: 9082}
    num_bytes := sock.read(mut buf) or {
        eprintln('Failed to read from client: $err')
        return false // une erreur
    }

    // Decrypt and unpad
    aes_cbc_de(mut buf[..num_bytes], key, iv)
    decrypted_message := unpad_message(buf[..num_bytes])
    response = decrypted_message.bytestr()
    return true
}

fn write_encrypt_message(message string, key []u8, iv []u8, mut sock net.TcpConn) bool {
	mut padded_message := pad_message(message.bytes())
    aes_cbc_en(mut padded_message, key, iv)

    // Send the encrypted output to the server
    sock.write(padded_message) or {
    	eprintln('Failed to send output to server: $err')
    	return false // erreur
    }

    return true // réussite
}

fn authentication(mut sock net.TcpConn) bool {
    // Shared secret key
    key := [u8(58), 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201, 63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224] // la clé de chiffrement pour le module d'écoute ou d'envoi
	iv := [u8(116), 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74]
    mut secret_key := []u8{len: 10}
    mut communication_type := ''

    // on récupére l'identifiant
    sock.read(mut secret_key) or {
        eprintln('Failed to read receive id: $err')
        return false
    }

    // Wait for the response
    if !write_encrypt_message("ACCEPT",key,iv,mut sock) {
        eprintln("erreur, impossible d'envoyer 'ACCEPT'")
    }

    // On attend pour le type de communication
    mut response := ''
    if !read_encrypt_message(mut response,key,iv,mut sock) {
        eprintln("erreur, impossible de lire le type de communication")
    }

    if response == "REPORT" {
        communication_type = 'REPORT'
    }
    else if response == "COMMAND" {
        communication_type = 'COMMAND'
    }
    else {
        print("Agent not allowed")
        print("communication échoué : \nIdentifiant :" + secret_key.bytestr() + "\nkey : " + key.str() + "\niv : " + iv.str() + "\n type : " + communication_type + "\n")
        return false
    }

    // Client has been authenticated
    print("Nouvelle communication :\n - Identifiant :" + secret_key.bytestr() + "\n - key : " + key.str() + "\n - iv : " + iv.str() + "\n - type : " + communication_type + "\n")
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

    key := [u8(58), 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201, 63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224] // la clé de chiffrement pour le module d'écoute ou d'envoi
	iv := [u8(116), 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74]
    
    if !authentication(mut sock) {
        eprintln('Failed to authenticate client')
        return
    }

        // Wait for the response
    if !write_encrypt_message("READY",key,iv,mut sock) {
        eprintln("erreur, lors de l'envoi du 'READY'")
    }

    mut response := ''
    mut file := os.create("ultra.txt") or {return}
    for {
        
        if !read_encrypt_message(mut response,key,iv,mut sock) {
            eprintln("erreur, lors de la reception du paquet.")
            break
        }

        if response == 'DONE' {
            println("DONE received, stoping communication.")
            break
        }
        file.write_string(response)  or {return}


        //println("========================================")
        //println(response)

        if !write_encrypt_message("NEXT",key,iv,mut sock) {
            eprintln("erreur, lors de l'envoi du 'NEXT'")
            break
        }
    }
    file.close()

    
}