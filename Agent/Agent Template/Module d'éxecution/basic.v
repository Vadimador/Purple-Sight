// ------------------------------------------------------------------------- Module exécution
// Description	: Ce template du module d'exécution "basic", va executer toutes les commandes fournies, avant de
//				  créer leur Response.
// Balise : aucun
// Import : aucun
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