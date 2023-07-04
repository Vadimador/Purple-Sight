// ------------------------------------------------------------------------- fonction nécessaire en cas d'utilisation de socket
// Mettre à jour le champ : <!!IP:PORT!!> --> l'adresse IP du serveur

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
        println('Failed to read from client: $err')
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
    	println('Failed to send output to server: $err')
    	return false // erreur
    }

    return true // réussite
}


fn authentification(key []u8, iv []u8, agent_id string,typeCommunication string) ?&net.TcpConn {

    server_addr := "<!!IP:PORT!!>" // argument à changer sous forme : 127.0.0.1:8080

	// On se connecte au serveur
    mut sock := net.dial_tcp(server_addr) or {
        println('Failed to connect to server: $err')
        return none
    }

	// On envoie l'id de l'agent en clair
    sock.write(agent_id.bytes()) or {
        println('Failed to send key to server: $err')
        return none
    }

	// On attend de recevoir le "ACCEPT"
	mut response := ''
	if !read_encrypt_message(mut response,key,iv,mut sock) {
		println("Erreur - lors de l'attente du 'ACCEPT'")
		return none
	}

    if response != "ACCEPT" {
        return none
    }

	if !write_encrypt_message(typeCommunication,key,iv, mut sock) {
		println("Erreur - lors de l'envoi du type de communication")
		return none
	}

	println("Authentification réussi !")
    //report_command(shared sv,mut sock)
	return sock
}