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
    public Voto insertarEleccion(@RequestBody Voto nuevoVoto){
        return repo.save(nuevoVoto);
    }
    
}
