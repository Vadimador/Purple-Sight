// ------------------------------------------------------------------------- Module envoie
// Description	: Ce template du module d'écoute "socket", se connecte au serveur de socket et attend une commande
//					- EXEC <commande> --> exécute une commande
//					- STOP --> arrète l'agent
// 					- STATUS --> affiche les status des modules
//					- SCAN --> lance un scan
// Balise : 
//			AUCUNE BALISE DE PARAMETRE N'EST NÉCESSAIRE
// Import et dépendances :
//			- Les fonction dans le fichier "socket-server-neccessary-functions.v" doivent être ajouté à l'agent si ce n'est pas déjà le cas
fn (shared sv SharedVariable) module_ecoute(){
	sv.set_module_state(Module.ecoute, ModuleState.running, "listening module running.")

	// on s'authentifie
	mut key := []u8{len: 32}
    mut iv := []u8{len: 16}
    mut agent_id := ''

	rlock sv {
		key = sv.cryptkey.clone()
		iv = sv.iv.clone()
		agent_id = sv.agent_identifier
	}

	// On s'authentifie au près du serveur
	mut sock := authentification(key,iv,agent_id,"COMMAND") or {
		sv.set_module_state(Module.ecoute,ModuleState.error,"Error - socket authentication for report failed.")
		return
	}

	sock.set_read_timeout(1 * time.hour)
	// on attend une commande
	mut cmd := ''
	for {
		sv.set_module_state(Module.ecoute, ModuleState.running, "waiting for next command...")
		if !read_encrypt_message(mut cmd, key, iv, mut sock) {
			sv.set_module_state(Module.ecoute,ModuleState.error,"Error - while waiting for the next command")
			return
		}

		// si c'est STATUS on renvoi le status puis on attend la prochaines commandes
		if cmd == 'STATUS' {
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

			if !write_encrypt_message(rst, key,iv,mut sock) {
				sv.set_module_state(Module.ecoute, ModuleState.error, "Error - while sending modules status")
				return
        	}

		}
		// si c'est SCAN on redémarre le tout pour envoyer un scan de la manière normal
		else if cmd == 'SCAN' {

			// on remplis le tableau des commandes à exécute
			lock sv, sv.response_list {
				sv.execution_commande_list = []
				 sv.response_list = []
				for i in 0 .. sv.commandes_list.len {
					sv.execution_commande_list << i
				}
			}

			m_execution := spawn sv.module_execution()
			m_envoie := spawn sv.module_envoie()
			m_execution.wait()
			m_envoie.wait()

			if !write_encrypt_message('scanning done.', key,iv,mut sock) {
            	eprintln("Erreur, lors de l'envoi de la réponse à 'STATUS'")
        	}
		}
		else if cmd == 'STOP' {
			sv.set_module_state(Module.ecoute, ModuleState.finish, "module stoped.")
			if !write_encrypt_message("stoping...", key,iv,mut sock) {
            	sv.set_module_state(Module.ecoute, ModuleState.error, "Error - while sending STOP response")
        	}
			return
		}
		// si c'est EXEC on exécute la commande puis renvoi la réponse, réponse max de 9082 caractères
		else if cmd.split(' ')[0] == 'EXEC' {
			cmd = cmd[4..].trim_space()
			println('cmd be like : "' + cmd + '"')

			rst := os.execute(cmd)
			cmd = rst.output
			if cmd.len > 9070 {
				cmd = cmd[0..9070]
			}

			if !write_encrypt_message(cmd, key,iv,mut sock) {
            	sv.set_module_state(Module.ecoute, ModuleState.error, "Error - while sending STOP response")
        	}
		}
		else {
			if !write_encrypt_message("incorrect command.", key,iv,mut sock) {
            	sv.set_module_state(Module.ecoute, ModuleState.error, "Error - while sending STOP response")
        	}
		}

	}

	sv.set_module_state(Module.ecoute, ModuleState.finish, "task completed.")
}