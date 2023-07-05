import net
import strconv
import time
import crypto.aes
import crypto.cipher
import os
import db.mysql

struct AgentConnection {

    id string
    key []u8
    iv []u8
    communication_type string
mut:
    sock net.TcpConn
}



fn getkey(receive_agent_id string) ?string {
    // Create connection
    mut connection := mysql.Connection{
        username: 'root',
        password: 'Azerty12',
        dbname: 'projet'
    }
    mut cryptkey := ""
    mut vecteur := ""
    // Connect to server
    var := connection.connect() or { return none }
    if var {
       var2 := connection.select_db('projet') or { return none }
            // Do a query
            if var2 {
                agent_query := connection.query("SELECT cryptkey, vecteur FROM socket WHERE id_unique = '$receive_agent_id'") or { return none }
//          mut cryptkey
                    for row in agent_query.rows() {
                    //id := row.vals[0].str
                        cryptkey = row.vals[0]
                        vecteur = row.vals[1]
                        println(cryptkey.str())
                        println(vecteur.str())
                       // return cryptkey + ':' + vecteur
                    }

                // Free the query result
                    unsafe {
                        agent_query.free()
                        return cryptkey + ':' + vecteur
                    }
                

            } else {
                println('Failed to select database')
                return none
            }
    } else {
        println('Failed to connect to server')
        return none
    }

    // Close the connection if needed
    connection.close()
}



/*
fn getkey(receive_agent_id string) ?string {
    // Create connection
    mut connection := mysql.Connection{
        username: 'root',
        password: 'Azerty12',
        dbname: 'projet'
    }
    mut cryptkey := ""
    mut vecteur := ""
    // Connect to server
    var := connection.connect() or { return none }
    if var {
       var2 := connection.select_db('projet') or { return none }
            // Do a query
            if var2 {
            agent_query := connection.query("SELECT cryptkey, vecteur FROM socket WHERE id_unique = '$receive_agent_id'") or { return none }
//          mut cryptkey
            for row in agent_query.rows() {
                //id := row.vals[0].str
                cryptkey = row.vals[0]
                vecteur = row.vals[1]
                println(cryptkey.str())
                println(vecteur.str())
		return cryptkey + ':' + vecteur
            }

            // Free the query result
            unsafe {
                agent_query.free()
		return cryptkey + ':' + vecteur
            }

        } else {
            println('Failed to select database')
            return none
        }
    } else {
        println('Failed to connect to server')
        return none
    }

    // Close the connection if needed
    connection.close()
}





fn getkey(receive_agent_id string) {
    // Create connection
    mut connection := mysql.Connection{
        username: 'root',
        password: 'Azerty12',
        dbname: 'projet'
    }

    // Connect to server
    var := connection.connect() or { return }
    if var {
       var2 := connection.select_db('projet') or { return }
       println("here")
            // Do a query
            if var2 {
	    println("HEEEEEEEEEREEEEEEEE")
            agent_query := connection.query("SELECT cryptkey, vecteur FROM socket WHERE id_unique = '$receive_agent_id'") or { return }
	    println("agent row" + agent_query.rows().str())	    
	    println("crypt" + agent_query.rows().vals[0].str())	    
//          mut cryptkey
            for row in agent_query.rows() {
               // id := row.vals[0].str
                cryptkey := row.vals[0]
                vecteur := row.vals[1]
                println(" CRYPT :" + cryptkey)
		println(" VEC :" + vecteur)
            }

            // Free the query result
            unsafe {
                agent_query.free()

            }

        } else {
            println('Failed to select database')
            return
        }
    } else {
        println('Failed to connect to server')
        return
    }

    // Close the connection if needed
    connection.close()
}
*/

fn is_agent_in_database(receive_agent_id string) bool {
    mut conn := mysql.Connection{
        username: 'root',
        password: 'Azerty12',
        dbname: 'projet'
    } //or { return false }

    // Connect to server
    connectdb := conn.connect() or { return false }
    selectdb := conn.select_db('projet') or { return false }
    if connectdb{
// Change the default database
        if selectdb{
            res := conn.query('select id_unique from agent') or { return false }
            for row in res.rows() {
                    if row.vals[0].str() == receive_agent_id {
                            return true
                            }
                        }
        }
    }
    conn.close()
    return false
}



fn get_id_and_command(response string) (string, string) {
    tokens := response.split(' ')
    if tokens.len < 2 {
        return '', ''
    }
    return tokens[0], tokens[1]
}

fn agent_exists(agent_id string, agent_connections []AgentConnection) bool {
    for agent in agent_connections {
        if agent.id == agent_id {
            return true
        }
    }
    return false
}

fn get_agent_socket(agent_id string, agent_connections []AgentConnection) net.TcpConn {
    for agent in agent_connections {
        if agent.id == agent_id {
            return agent.sock
        }
    }
    // In case no matching agent is found, you may want to handle this case
    panic("No agent found with id: " + agent_id)
}

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
        eprintln("Failed to read from client: $err")
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
        eprintln("Failed to send output to server: $err")
        return false // erreur
    }

    return true // réussite
}

fn get_talker_id(mut id &string) bool {
    mut file := os.open("talker_id.txt") or {
        eprintln('Warning - cannot open talker file')
        return false
    }
    defer { file.close() }
    bytes := file.read_bytes(12)
    id = bytes.bytestr()

    return true
}




fn authentication(mut sock net.TcpConn, shared agent_connections []AgentConnection) ?AgentConnection {
    // Shared secret keyi
    mut key := []u8{}
    mut iv := []u8{}
//    mut key := [u8(58), 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201,                                                                                                                         63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224] // la clé de chiffrement pour le module d'écoute ou d'envoi
//    mut iv := [u8(116), 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74]
    mut secret_key := []u8{len: 12}
    mut communication_type := ''

    // on récupére l'identifiant
    sock.read(mut secret_key) or {
        eprintln("Failed to read receive id: $err")
        return none
    }
    //println(secret_key.str())
    receive_agent_id := secret_key.bytestr()
 

    // Fetch the agent id from the file
    mut file_agent_id := ''
    if !get_talker_id(mut file_agent_id) {
        eprintln('Failed to fetch agent id from file')
    }


    println(receive_agent_id)
    // Compare the received agent id with the one present in the file
    if receive_agent_id == file_agent_id {
        communication_type= "TALKER"
        mut agent := AgentConnection{
                id: receive_agent_id,
                key: key,
                iv: iv,
                sock: sock,
                communication_type: communication_type,
                }
        //agent_connections << agent
        return agent
        // If agent_id not found in the file, then check the database
        }else if !is_agent_in_database(receive_agent_id){
                eprintln("Erreur, l'identifiant de l'agent n'a pas été trouvé dans la base de données ni dans le fichier.")
                return none
        }//else {
                //println("Erreur, Identifiant n'est ni présent dans le talker_id.txt ni dans la database.")
                //continue
  //  }

     mut keyvec := getkey(receive_agent_id) or { return none }
     if keyvec == ':'{
	     println("Agent sans clé de chiffrement")
	     return none
	     }

     //println("keyvec:" + keyvec)
     tabkeyvec := keyvec.split(':')
     
     for octet in tabkeyvec[0].split(','){
	    strint := (strconv.parse_uint(octet, 10, 8) or { return none })
	   // println (typeof(u8(strint)))
	    key << u8(strint)
	    //println (typeof(u8(strconv.parse_int(octet, 10, 8))))

	    }
	    
     for octet in tabkeyvec[1].split(','){
            strint := (strconv.parse_uint(octet, 10, 8) or { return none })
           // println (typeof(u8(strint)))
            iv << u8(strint)
            //println (typeof(u8(strconv.parse_int(octet, 10, 8))))
            }
	    println ("new KEY" + key.str())
	    println ("new IV" + iv.str())


    // Write ACCEPT
    if !write_encrypt_message("ACCEPT", key, iv, mut sock) {
        eprintln("erreur, impossible d'envoyer 'ACCEPT'")
        return none
    }

    // On attend pour le type de communication
    mut response := ''
    if !read_encrypt_message(mut response, key, iv, mut sock) {
        eprintln("STOP READ, impossible de lire le type de communication")
        return none
    }

    if response == "REPORT"{
        communication_type = "REPORT"
          }
    else if response == "COMMAND"{
        communication_type = "COMMAND"
         }
  //  else if response == "TALKER"{
   //     communication_type = "TALKER"
   // }
    else{
            println("Erreur, impssible de lire type de communication")
            sock.close() or {
                   eprintln("Erreur, impossible de fermer la socket")
                   }
            return none
            }
//    communication_type := response
  //  agent.communication_type = response
    mut agent := AgentConnection{
        id: receive_agent_id,
        key: key,
        iv: iv,
        sock: sock,
        communication_type: communication_type,
    }
    agent_connections << agent
    return agent
}

fn receive_report(mut agent AgentConnection, shared agent_connections []AgentConnection){
    if agent.communication_type == "REPORT" {

        // Send READY to agent
        if !write_encrypt_message("READY", agent.key, agent.iv, mut agent.sock) {
            eprintln("erreur, impossible d'envoyer 'READY'")
            return
        }



        mut response := ''
        mut file := os.create("ultra.txt") or {return}
        for 
		{
                if !read_encrypt_message(mut response,agent.key,agent.iv,mut agent.sock) {
                eprintln("erreur, lors de la reception du paquet.")
                break
                }

                if response == 'DONE' {
                println("DONE received, stoping communication.")
                break
                }
                file.write_string(response)  or 
			{println("Erreur, $err")}


        //println("========================================")
        //println(response)

                if !write_encrypt_message("NEXT",agent.key,agent.iv,mut agent.sock) {
                eprintln("erreur, lors de l'envoi du 'NEXT'")
                break
                }
        }
        file.close()


/*
        // Prepare to write command outputs to file
        mut file := os.create('command_output.txt') or {
            eprintln("Failed to create file: $err")
            return
        }

        // Listen for command outputs

        for {
            mut response := ''
            if !read_encrypt_message(mut response, agent.key, agent.iv, mut agent.sock) {
                eprintln("STOP READ, impossible de lire le type de communication")
                return
            }

            if response == "COMMAND" {
                if !write_encrypt_message("NEXT", agent.key, agent.iv, mut agent.sock) {
                    eprintln("erreur, impossible d'envoyer 'NEXT'")
                    return
                }
                continue

            } else if response == "DONE" {
                break
            } else {
                file.write_string(response + '\n') or {
                    eprintln("Failed to write to file: $err")
                }
            }
        }
        // Move the file to the right location (to be specified)
        os.mv('command_output.txt', '/path/to/right/location') or {
            eprintln("Failed to move file: $err")
            return
        }
*/
        println('Command outputs received and file moved successfully.')

    }else {
        print("Agent not allowed")
        print("communication échoué : \nIdentifiant :" + agent.id + "\nkey : " + agent.key.str() + "\niv : " + agent.iv.str() + "\ntype : " + agent.communication_type + "\n")
        return
    }

    //agent_connections << AgentConnection{
    //    id: receive_agent_id,
    //    key: key,
    //    iv: iv,
    //    sock: sock,
    //    communication_type: communication_type,
    //}
    //Client has been authenticated
   // print("Nouvelle communication :\n - Identifiant :" + secret_key.bytestr() + "\n - key : " + key.str() + "\                                                                                                                        n - iv : " + iv.str() + "\n - type : " + communication_type + "\n")
    //return true
}

fn receive_cmd(mut agent AgentConnection, shared agent_connections []AgentConnection, mut sock net.TcpConn){
    if agent.communication_type == "COMMAND" {
        rlock agent_connections{
                if !agent_exists(agent.id, agent_connections){
                    println("Erreur,Identifiant de l'agent n'est pas dans le tableau des agents")
                    return
                }else{
                    sock.set_read_timeout(1 * time.hour)
		    sock.set_write_timeout(1 * time.hour)
            //keep going the connections
                return
                }
        }
        }
    return
}

fn receive_talker(mut agent AgentConnection, shared agent_connections []AgentConnection, mut sock net.TcpConn){
    if agent.communication_type == "TALKER"{
        sock.write('WAITING'.bytes()) or {
                eprintln('Failed to write \'WAITING\' receive id: $err')
                return
    }

    mut command := []u8{len: 9082}
    num_bytes := sock.read(mut command) or {
                eprintln('Failed to write \'READY\': $err')
                return
    }
    println("var command: " + command.str())
    mut text_command := (command[..num_bytes]).bytestr().trim_space()

    println("var text_command : " + text_command.bytes().str())

    // Split the command into its components
    command_parts := text_command.split(' ')
    println("parse : $command_parts")
    // Determine the command type
    if command_parts.len > 0 {
        command_type := command_parts[0]
        println("command type :" + command_type.bytes().str())
        if command_type == "LIST" {
            println("In the list condition !!!!")
            // Send a list of all connected agents to the talker
            mut agent_list := ""
            for agent_conn in agent_connections {
                agent_list += agent_conn.id + "\n"
            }
            sock.write(agent_list.bytes()) or {
                        eprintln('Failed to write the agent list: $err')
                        return
            }

        } else if command_type == "COMMAND" {
	    mut response := ""
            // Send a command to a specific agent
            if command_parts.len >= 3 {
                mut target_id := command_parts[1]
                command_to_send := command_parts[2]

                // Find the target agent
                rlock agent_connections{
                    if agent_exists(target_id, agent_connections) {
                        for mut agent_conn in agent_connections {
                            if agent_conn.id == target_id {
                            // Send the command to the target agent
			       if !write_encrypt_message(command_to_send,agent_conn.key,agent_conn.iv,mut agent_conn.sock){
				       eprintln('Failed to send the command to the agent') 
				       break }
                               // agent_conn.sock.write(command_to_send.bytes()) or {
                                //    eprintln('Failed to send the command to the agent: $err')
                                //    return
                               // }
			       if !read_encrypt_message(mut response,agent_conn.key,agent_conn.iv,mut agent_conn.sock){
				       eprintln('Failed to send the command to the agent') 
				       break }
				sock.write(response.bytes()) or {
					eprintln('Failed to send the response to the talker : $err')
					break
					}
                               	break
                            }
                        }
                    }else {
                        sock.write("Agent with id : $target_id not found.".bytes()) or {
                            eprintln('Failed to write the agent not found message: $err')
                            return
                        }
                    }
                }
            }
        } else if command_type == "CLOSE" {
            // Close a specific agent
            if command_parts.len >= 2 {
                target_id := command_parts[1]

                // Find and close the target agent
                rlock agent_connections{

                    if agent_exists(target_id, agent_connections) {
                        for mut agent_conn in agent_connections {
                            if agent_conn.id == target_id {
                            // Close the agent connection
                                agent_conn.sock.close() or {
                                    eprintln('Failed to close the agent connection: $err')
                                    return
                                }
                                break
                            }
                        }
                    }else{
                        sock.write("Agent with id : $target_id not found.".bytes()) or {
                            eprintln('Failed to write the agent not found message: $err')
                            return
                        }
                    }

                }
            }
        }
    // On renvoie la réponse, max 9082 caractères
    sock.write('commande reçu !'.bytes()) or {
                eprintln('Failed to write the command response: $err')
                return
    }
    }
}
}

fn main() {
    // Define agent_connections here
    shared agent_connections := []AgentConnection{}

    listen_port := "0.0.0.0:8080"
    mut listener := net.listen_tcp(net.AddrFamily.ip, listen_port) or {
        eprintln("Failed to create listener: $err")
        return
    }

    println("Listening on port: $listen_port")
    for {
        mut sock := listener.accept() or {
            eprintln("Failed to accept connection: $err")
            continue
        }

        go handle_client(mut sock, shared agent_connections)
    }
}

fn handle_client(mut sock net.TcpConn, shared agent_connections []AgentConnection) {
    //defer { sock.close() or {} }

    mut agent := authentication(mut sock, shared agent_connections) or {
        eprintln("Failed to authenticate client")
        return
    }

    if agent.communication_type == "REPORT"{
        receive_report(mut agent, shared agent_connections)
	sock.close() or {}
        }
    else if agent.communication_type == "TALKER" {
        receive_talker(mut agent, shared agent_connections, mut sock)
	sock.close() or {}
    }
    else{
        receive_cmd(mut agent, shared agent_connections, mut sock)
    }
}
 
