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

	mut file := os.create("talker_id.txt") or {
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
	server_addr := '127.0.0.1:8080'

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

fn main() {

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