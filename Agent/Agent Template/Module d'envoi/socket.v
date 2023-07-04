// ------------------------------------------------------------------------- Module envoie
// Description	: Ce template du module d'envoi "socket", créer simplement un couple header/output pour chaque Response
//				  Il va ensuite utiliser le serveur de socket installé sur Purple Sight pour transmettre ses données de manière chiffré
//				  en parallèle de l'exécution des commandes par le module d'exécution.
// Balise : 
//			AUCUNE BALISE DE PARAMETRE N'EST NÉCESSAIRE
// Import et dépendances :
//			- Les fonction dans le fichier "socket-server-neccessary-functions.v" doivent être ajouté à l'agent si ce n'est pas déjà le cas

fn (shared sv SharedVariable) module_envoie() {

	sv.set_module_state(Module.envoie,ModuleState.started,"starting...")

	// On récupère clé de chiffrement
	mut key := []u8{len: 32}
    mut iv := []u8{len: 16}
    mut agent_id := ''

	rlock sv {
		key = sv.cryptkey.clone()
		iv = sv.iv.clone()
		agent_id = sv.agent_identifier
	}

	// On s'authentifie au près du serveur
	mut sock := authentification(key,iv,agent_id,"REPORT") or {
		sv.set_module_state(Module.envoie,ModuleState.error,"Error - socket authentication for report failed.")
		return
	}

	mut retour := ''
	if !read_encrypt_message(mut retour, key, iv, mut sock) {
		sv.set_module_state(Module.envoie,ModuleState.error,"Error - socket failure when waiting for 'READY'.")
		return
	}

	if retour != 'READY' {
		sv.set_module_state(Module.envoie, ModuleState.error, "Error - Bad protocol or decryption, stoping report.")
		return
	}

	mut index := 0 // l'index correspondant à la command ou il en est

	// on attend que le module d'éxecution est running
	mut s := ModuleState.unknown

	for {
		
		rlock sv.module_state {
			s = sv.module_state[Module.execution]
		}
		// dès que le module d'exécution se termine, on break
		if s == ModuleState.running {
			break
		}

		time.sleep(10 * time.millisecond)
	}

	// on attend qu'une commande soit ajouté
	for {
		rlock sv.response_list {
			// dès que le module d'exécution se termine, on break
			if sv.response_list.len > 0 {
				break
			}
		}
		time.sleep(10 * time.millisecond)
	}

	mut response := Response{}
	mut header := ""
	mut full_response := ""
	mut post_next_command := true
	mut chunks := []string{}
	mut size_chunk := 0
	for {
		// on récupère la commande de l'index
        rlock sv.response_list {
            response = sv.response_list[index]
        }

		// on formate ce qu'il faut envoyer
		header = sv.commandes_list[response.index].id
		header += " "  + response.exit_code.str()
		header += " " + (response.output.count("\n") + 1).str() + "\n"
		full_response = header + response.output + "\n"

		// on calcule avec un % 9082 pour voir combien de paquet il faudra envoyer
		size_chunk = 9070

		chunks = []string{}
		
		for i := 0; i < full_response.len; i += size_chunk {
			if i+size_chunk > full_response.len {
				size_chunk = full_response.len - i
			}
			chunk := full_response[i..i+size_chunk]
			chunks << chunk
		}

		// boucle d'envoi des paquets pour une commande
		for chunk in chunks {

			// on envoie un paquet
			if !write_encrypt_message(chunk,key,iv,mut sock) {
				sv.set_module_state(Module.envoie, ModuleState.error, "Error - while sending a chunk.")
				return
			}
			// on attend le NEXT, si on reçoit le next mais qu'il n'y a plus de paquet on break
			if !read_encrypt_message(mut retour, key, iv, mut sock) {
				sv.set_module_state(Module.envoie, ModuleState.error, "Error - while waiting for 'NEXT'")
				return
			}

			if retour != 'NEXT' {
				sv.set_module_state(Module.envoie, ModuleState.error, "Error - Bad protocol, waiting for 'NEXT' received : " + retour)
				return
			}

		}

		rlock sv {
			println( sv.commandes_list[response.index].id.str() + " transmitted.")
		}
		
		// on attend qu'une nouvelle commande est ajouté, si le module d'éxecution se termine on break
		for {
			rlock sv.response_list, sv.module_state {
				if sv.response_list.len - 1 > index {
					index += 1
					post_next_command = true
					break
				}

				if sv.module_state[Module.execution] == ModuleState.finish {
					post_next_command = false
					break
				}
			}
			time.sleep(10 * time.millisecond)
		}

		if post_next_command == false {
			break
		}

	}

	// on indique que la transmission du rapport est terminé
	if !write_encrypt_message('DONE',key,iv,mut sock) {
		sv.set_module_state(Module.envoie,ModuleState.error,"Error - when sending 'DONE'.")
		return
	}

	sock.close() or {
		sv.set_module_state(Module.envoie,ModuleState.error,"Error - cannot close the open socket.")
		return
	}

	sv.set_module_state(Module.envoie,ModuleState.finish,"task completed.")
}