import net
import crypto.aes
import crypto.cipher

struct SharedVariable {
	agent_identifier string = "<id-agent>" // de la forme "agent-x" ou x est le numèro de l'agent
	cryptkey []u8 = [u8(58), 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201, 63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224] // la clé de chiffrement pour le module d'écoute ou d'envoi
	// exemple de cryptkey : 58, 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201, 63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224
	iv []u8 = [u8(116), 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74] // le vecteur d'initialisation pour le chiffrement aes-256-cbc
	// exemple d'iv : 116, 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74
}

fn main(){
	shared shared_variable := SharedVariable{}
	authentification(shared shared_variable,"REPORT")

}

// ------------------------------------------------------------------------- fonction nécessaire en cas d'utilisation de socket
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

fn authentification(shared sv &SharedVariable, typeCommunication string) bool {
	mut key := []u8{len: 32}
    mut iv := []u8{len: 16}
    mut agent_id := ''
    server_addr := "127.0.0.1:8080" // argument à changer

	rlock sv {
		key = sv.cryptkey.clone()
		iv = sv.iv.clone()
		agent_id = sv.agent_identifier
	}
	//print('connect ...')
	// On se connecte au serveur
    mut sock := net.dial_tcp(server_addr) or {
        println('Failed to connect to server: $err')
        return false
    }
	//print('write id ...')
	//println(agent_id.bytes())
	// On envoie l'id de l'agent en clair
    sock.write(agent_id.bytes()) or {
        println('Failed to send key to server: $err')
        return false
    }

	//print('wait response ...')
	// On attend de recevoir le "ACCEPT"
	mut response := ''
	if !read_encrypt_message(mut response,key,iv,mut sock) {
		println("Erreur - lors de l'attente du 'ACCEPT'")
		return false
	}

    if response == "ACCEPT" {
        println("ACCEPT - reçu.")
    }
    else {
        return false
    }

	if !write_encrypt_message(typeCommunication,key,iv, mut sock) {
		println("Erreur - lors de l'envoi du type de communication")
		return false
	}

	print("Authentification réussi !")
    report_command(shared sv,mut sock)
	return true
}

fn report_command(shared sv &SharedVariable, mut sock net.TcpConn) {
    mut tab := ["test1","test2","test3","test4","test5","test6","test7","test8","test9","test10","test11"]
    mut index := 0

    mut key := []u8{len: 32}
    mut iv := []u8{len: 16}
    mut agent_id := ''
    server_addr := "127.0.0.1:8080" // argument à changer

	rlock sv {
		key = sv.cryptkey.clone()
		iv = sv.iv.clone()
		agent_id = sv.agent_identifier
	}

    mut response := ''
    if !read_encrypt_message(mut response,key,iv,mut sock) {
        eprintln("erreur, reception 'READY' impossible")
        return
    }

    if response != 'READY' {
        eprintln("erreur, reception 'READY' impossible reçu à la place : " + response)
        return
    }
    else {
        println("READY received")
    }

    print("on envoi du paté ")

    for t in tab {

        // on envoie un paquet
        if !write_encrypt_message(t,key,iv,mut sock) {
            eprintln("erreur, lors d'un paquet")
        }

        // on attend de recevoir le NEXT pour continuer
        if !read_encrypt_message(mut response,key,iv,mut sock) {
            eprintln("erreur, lors de la réception de 'NEXT'")
            break
        }

        if response != 'NEXT' {
            eprintln("incorrect protocol - no 'NEXT'")
            break
        }

    }

    if !write_encrypt_message('DONE',key,iv,mut sock) {
            eprintln("erreur, lors d'un paquet")
        }
}