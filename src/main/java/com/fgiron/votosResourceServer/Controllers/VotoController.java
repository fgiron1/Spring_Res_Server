package com.fgiron.votosResourceServer.Controllers;

import com.fgiron.votosResourceServer.Advice.EleccionNotFoundException;
import com.fgiron.votosResourceServer.Models.Eleccion;
import com.fgiron.votosResourceServer.Models.Voto;
import com.fgiron.votosResourceServer.Repositories.VotoRepository;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 *
 * @author fgiron
 */

@RestController
public class VotoController {

    private final VotoRepository repo;
    
    public VotoController(VotoRepository repo){
        this.repo = repo;
    }
    
    @PostMapping("/voto")
    public int votar(@RequestBody int id_elecciones,
                      @RequestBody int id_partido,
                      @RequestBody String nombre_1,
                      @RequestBody String nombre_2,
                      @RequestBody String nombre_3,
                      @RequestBody String apellido_1,
                      @RequestBody String apellido_2,
                      @RequestBody String apellido_3){
        return repo.votar(id_elecciones, id_partido, nombre_1, nombre_2, nombre_3, apellido_1, apellido_2, apellido_3);
    }
    
}
