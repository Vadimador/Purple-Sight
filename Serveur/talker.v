import os 
import net
import rand

enum CommandResult as u8 {
	ok = 0
	error = 1
	bad_argument = 2
}


fn help() string {
	mut rst := ''
	rst = "Usage : \n./talker <argument>\n\t--list-agents : list every connected agent\n\t--send-command <agent id> '<command>' : send a command to an connected agent\n\t--close <agent id> : close an connected agent\n"

	return rst
}

fn list_agents(id string) CommandResult {

	response := talker_command(id,"LIST") or {
		eprintln('Error - error while asking the list of connected agents')
		return CommandResult.error
	}

	println(response)

	return CommandResult.ok
}

fn send_command(id string) CommandResult {

	if os.args.len < 4 {
		return CommandResult.bad_argument
	}
	/*mut fullcommand := ''
	for i in os.args[3..]{
		fullcommand += i + ' '
	}
	fullcommand.trim_space()*/

	response := talker_command(id,"COMMAND " + os.args[2] + " " + os.args[3]) or {
		eprintln('Error - error while asking the list of connected agents')
		return CommandResult.error                                                                    
	}

	println(response)

	return CommandResult.ok
}

fn close(id string) CommandResult {

	if os.args.len < 3 {
		return CommandResult.bad_argument
	}

	response := talker_command(id,"CLOSE " + os.args[2]) or {
		eprintln('Error - error while asking the list of connected agents')
		return CommandResult.error
	}

	println(response)
	return CommandResult.ok
}

fn generate_identifier() string {
    alphabet := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
    mut identifier := ""
    
    for i := 0; i < 12; i++ {
        random_index := rand.intn(alphabet.len) or {return ""}
        identifier += alphabet.substr(random_index,random_index + 1)
    }
    
    return identifier
}

fn create_id() ?string {
	identifier := generate_identifier()
	
	if identifier == "" {
		return none
	}

	mut path := get_config("TALKER_ID_PATH") or {
		return none
	}
	create_complete_file_and_path(path + '/','talker_id.txt','')
	mut file := os.create(path+'/talker_id.txt') or {
		eprintln('Error - cannot open the talker id file')
		return none
	}
	defer { file.close ()}

	file.write_string(identifier) or {
		eprintln('Error - cannot write the talker id file')
		return none
	}

	file.close()

	return identifier
}

fn talker_command(id string, command string) ?string {

	mut response := []u8{len:7}
	command_port := get_config("COMMAND_PORT") or {
		return none
	}
	server_addr := '127.0.0.1:' + command_port

	println("server_addr : $server_addr")

	// on se connecte au serveur
	mut sock := net.dial_tcp(server_addr) or {
        println('Failed to connect to server: $err')
        return none
    }
	
	defer { sock.close() or {}}

	// on écrit l'identifiant mis à jour
	sock.write(id.bytes()) or {
		eprintln('Failed to read receive id: $err')
		return none
    }

	// on récupère la réponse
	sock.read(mut response) or {
		eprintln('Failed to read receive id: $err')
		return none
    }

	// si ce n'est pas WAITING on sort
	if response.bytestr() != 'WAITING' {
		eprintln('Error - Bad protocol or connection refused by the server')
		sock.close() or {
			eprintln('Error - error when closing the socket')
			return none
		}
		return none
	}

	// on écrit la commandes voulu
	sock.write(command.bytes()) or {
		eprintln('Error - Could not write the command')
		return none
    }

	// on récupère la réponse maximum 9082 caractères
	response = []u8{len:9082}
	sock.read(mut response) or {
		eprintln('Error - Could not read response : $err')
		return none
    }

	return response.bytestr()
}

// créé le chemin complet ainsi que le fichie et son contenu par defautl
// 		- le path doit se finir par '/' ou le filename doit commencer par '/'
//		- si le filename est vide, le fichier ne sera pas créé mais le chemin oui
// 		- si default_data est vide le fichier ne sera pas remplis
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

// fonction récupèrant le résultat du fichier de config
fn get_config(key string) ?string {
	chemin := "etc/purple/"
	config_name := "purple.config"
	create_complete_file_and_path(chemin, config_name,'REPORT_PORT:9090\nCOMMAND_PORT:9091\nLOG_PATH:/var/log\nTALKER_ID_PATH:etc/purple')

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


	/*mut rsp := get_config("COMMAND_PORT") or {
		return
	}
	println('like : $rsp')

	return*/

	if os.args.len < 2 {
		print(help())
		return
	}

	mut retour := CommandResult.error
	commands := ['--list-agents','--send-command','--close']
	mut command_index := -1

	for i := 0; i < commands.len; i++ {
		if os.args[1] == commands[i] {
			command_index = i
			break
		}
	}

	if command_index == -1 {
		print(help())
		return
	}


	// on récupère l'identifiant
	identifier := create_id() or {
		eprintln('Error - Got an error while generating the talker id')
		return
	}

	if command_index == 0 {
		retour = list_agents(identifier)
	}
	else if command_index == 1 {
		retour = send_command(identifier)
	}
	else if command_index == 2 {
		retour = close(identifier)
	}

	if retour == CommandResult.bad_argument {
		print(help())
	}


}