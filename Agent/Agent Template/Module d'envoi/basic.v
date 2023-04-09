time

// ------------------------------------------------------------------------- Module envoie
// Description	: Ce template du module d'envoi "basic", créer simplement un couple header/output pour chaque Response
//				  dans un fichier. Il attend jusqu'à ce que le module d'éxecution ai terminé.
// Balise : 
//			- <!!filename!!> : le nom du fichier de dump
// Import :
//			- time
fn (shared sv SharedVariable) module_envoie() {
	dump_filename := <!!filename!!> // argument modifiable à la compilation

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