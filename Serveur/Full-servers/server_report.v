import net
import net.http
import strconv
import time
import crypto.aes
import crypto.cipher
import os
import db.mysql
import rand

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
fn getname(name string) ?string {
    mut connection := mysql.Connection{
        username: 'root',
        password: 'Azerty12',
        dbname: 'projet'
    }
    mut nom_agent := ""
    var := connection.connect() or { return none }
    if var {
       var2 := connection.select_db('projet') or { return none }
       if var2 {
	       agent_query := connection.query("SELECT nom FROM agent WHERE id_unique = '$name'") or { return none}
	       for row in agent_query.rows(){
		      nom_agent = row.vals[0]
		      println("nom agent: $nom_agent")
	       }
	       unsafe{
		       agent_query.free()
		       return nom_agent
		       }
	      }else{
		      println("Failed to select database")
		      return none
		      }
	}else{
		println("Failed to connect to server")
		return none
	}
	connection.close()
}
   	
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

fn log_event(event string) {
    log_file_path := 'serveur_report.log'

    // Open the log file in append mode, or create it if it does not exist
    mut log_file := os.open_append(log_file_path) or {
        eprintln("Failed to open the log file: $err")
        return
    }
    defer {
        log_file.close()
        }

    // Write the event to the log file, along with a timestamp
    log_file.write_string("[${time.now()}]: $event\n") or {
        eprintln("Failed to write to the log file: $err")
    }
}


//fn get_id_and_command(response string) (string, string) {
//    tokens := response.split(' ')
//    if tokens.len < 2 {
//        return '', ''
//    }
//    return tokens[0], tokens[1]
//}

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





fn authentication(mut sock net.TcpConn, shared agent_connections []AgentConnection) ?AgentConnection {
    // Shared secret keyi
    mut key := []u8{}
    mut iv := []u8{}
    mut secret_key := []u8{len: 12}
    mut communication_type := ''

    // on récupére l'identifiant
    sock.read(mut secret_key) or {
        eprintln("Failed to read receive id: $err")
	log_event("Failed to read receive id")
        return none
    }
    //println(secret_key.str())
    receive_agent_id := secret_key.bytestr()


    // Fetch the agent id from the file
    if !is_agent_in_database(receive_agent_id){
	    eprintln("Erreur, l'identifiant de l'agent n'a pas été trouvé dans la base de données ni dans le fichier.")
	    log_event("Erreur, l'identifiant de l'agent n'a pas été trouvé dans la base de données ni dans le fichier.")
            return none
	    }

    println(receive_agent_id)
    // Compare the received agent id with the one present in the file

     mut keyvec := getkey(receive_agent_id) or { return none }
     if keyvec == ':'{
	     println("Agent sans clé de chiffrement")
	     log_event("Agent sans clé de chiffrement")
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
	  //  println ("new KEY" + key.str())
	 //   println ("new IV" + iv.str())


    // Write ACCEPT
    if !write_encrypt_message("ACCEPT", key, iv, mut sock) {
        eprintln("erreur, impossible d'envoyer 'ACCEPT'")
	log_event("erreur, impossible d'envoyer 'ACCEPT'")
        return none
    }

    // On attend pour le type de communication
    mut response := ''
    if !read_encrypt_message(mut response, key, iv, mut sock) {
        eprintln("STOP READ, impossible de lire le type de communication")
	log_event("STOP READ, impossible de lire le type de communication")
        return none
    }

    if response == "REPORT"{
        communication_type = "REPORT"
          }
    else{
            println("Erreur, impssible de lire type de communication")
	    log_event("Erreur, impssible de lire type de communication")
            sock.close() or {
                   eprintln("Erreur, impossible de fermer la socket")
		   log_event("Erreur, impossible de fermer la socket")
                   }
            return none
            }
    mut agent := AgentConnection{
        id: receive_agent_id,
        key: key,
        iv: iv,
        sock: sock,
        communication_type: communication_type,
    }
    println("Fin de l'authentification id : $agent.id comtype : $agent.communication_type\n")
    log_event("Fin de l'authentification id : $agent.id comtype : $agent.communication_type")

    agent_connections << agent
    return agent
}

fn receive_report(mut agent AgentConnection, shared agent_connections []AgentConnection){
    if agent.communication_type == "REPORT" {
	println("Enter in REPORT\n")
        // Send READY to agent
        if !write_encrypt_message("READY", agent.key, agent.iv, mut agent.sock) {
            eprintln("erreur, impossible d'envoyer 'READY'")
	    log_event("erreur, impossible d'envoyer 'READY'")
            return
        }
	println("REPORT FUNCTION Envoie du READY reussi !!!\n")


	
        mut response := ''
//	mut rand := rand.new_default()
	unique_file_name := rand.int()
	file_name := "report-${unique_file_name}.txt"
        mut file := os.create(file_name) or {return}
        for 
		{
                if !read_encrypt_message(mut response,agent.key,agent.iv,mut agent.sock) {
                eprintln("erreur, lors de la reception du paquet.")
		log_event("erreur, lors de la reception du paquet.")
                break
                }

                if response == 'DONE' {
                println("DONE received, stoping communication.")
		log_event("DONE received, stoping communication.")
                break
                }
                file.write_string(response)  or 
			{println("Erreur lors de l'écriture dans le fichier $file")
			log_event("Erreur lors de l'écriture dans le fichier $file")}



        //println("========================================")
        //println(response)

                if !write_encrypt_message("NEXT",agent.key,agent.iv,mut agent.sock) {
                eprintln("erreur, lors de l'envoi du 'NEXT'")
		log_event("erreur, lors de l'envoi du 'NEXT'")
                break
                }
        }
        file.close()
	os.chmod(file_name, 0o777) or {
		eprintln(err)
                }
        new_path := '/home/ritchie/preprod/Web/data/data/${file_name}'

	os.mv(file_name, new_path) or {
		eprintln("Erreur lors du déplacement du fichier : $err")
                log_event("Erreur lors du déplacement du fichier")
		}

        println('Command outputs received and file moved successfully.')
	log_event("Command outputs received and file moved successfully.")
        
	nom := getname(agent.id) or {
		eprintln("Erreur lors de récupération du nom de l'agent")
		log_event("Erreur lors de récupération du nom de l'agent")
		return
		}
	//14.20.22.200:8888/Web/parseur.php?agents={$nom}$ainogad=1%22
	mut url :="http://14.20.22.200:8888/Web/parseur.php?agent=" + nom + "&ainogad=1"
	http.get(url) or {
		eprintln("Erreur de la requete GET")
		log_event("Erreur de la requete GET")
		}

    }else {
        print("Agent not allowed")
        print("communication échoué : \nIdentifiant :" + agent.id + "\nkey : " + agent.key.str() + "\niv : " + agent.iv.str() + "\ntype : " + agent.communication_type + "\n")
	log_event("communication échoué : \nIdentifiant :" + agent.id + "\nkey : " + agent.key.str() + "\niv : " + agent.iv.str() + "\ntype : " + agent.communication_type) 
        return
    }

}

fn create_complete_file_and_path(path string, filename string, default_data string) {
	if !os.exists(path+filename) {
		mut dirs := path.split('/')
		mut path_construction := ''
		for d in dirs {
			if d != '' {
				if os.exists(path_construction + d) {
					path_construction += d + '/'
					continue
				}
				os.mkdir(path_construction + d) or {
					eprintln("[i] - fail when creating '$path_construction$d' $err")
					return
				}
				path_construction += d + '/'
			}
		}
		if filename != '' {
			mut file := os.create(path + filename) or {
				eprintln("[i] - folder created, but cannot create $filename : $err")
				return
			}
			defer { file.close()}
			if default_data != '' {
				file.write_string(default_data) or {
					eprintln("[i] - folder created, config file created, but cannot write default configuration : $err")
					return
				}
			}
			file.close()
		}

	}
}

fn get_config(key string) ?string {
	chemin := "/etc/purple/"
	config_name := "purple.config"
	create_complete_file_and_path(chemin, config_name,'REPORT_PORT:9090\nCOMMAND_PORT:9091\nLOG_PATH:/var/log\nTALKER_ID_PATH:/etc/purple')

	mut file := os.read_file(chemin + config_name) or {
		eprintln("cannot read config file, verify that $chemin$config_name exist : $err")
		return none
	}

	mut rst := ''
	mut lines := file.trim_space().split('\n')
	for line in lines {
		keyval := line.split(':')
		if keyval[0] == key {
			rst = keyval[1]
			break
		}
	}

	return rst
}


fn main() {
    // Define agent_connections here
    shared agent_connections := []AgentConnection{}
    report_port := get_config("REPORT_PORT") or {
            log_event("Une erreur est survenue lors de la récupération de la configuration")
            return
    }
    listen_port := "0.0.0.0:$report_port"
    log_event("En ecoute sur 0.0.0.0:$report_port")

    mut listener := net.listen_tcp(net.AddrFamily.ip, listen_port) or {
        eprintln("Failed to create listener: $err")
	log_event("Failed to create listener")
        return
    }

    println("Listening on port: $listen_port")
    for {
        mut sock := listener.accept() or {
            eprintln("Failed to accept connection: $err")
	    log_event("Failed to accept connection")
            continue
        }

        spawn handle_client(mut sock, shared agent_connections)
    }
}

fn handle_client(mut sock net.TcpConn, shared agent_connections []AgentConnection) {
    //defer { sock.close() or {} }

    mut agent := authentication(mut sock, shared agent_connections) or {
        eprintln("Failed to authenticate client")
        return
    }
    println(" HANDLE_CLIENT id : $agent.id  comtype : $agent.communication_type") 
    if agent.communication_type == "REPORT"{
        receive_report(mut agent, shared agent_connections)
	sock.close() or {}
        }
}
 
