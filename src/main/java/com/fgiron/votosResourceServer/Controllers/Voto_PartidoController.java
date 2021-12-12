package com.fgiron.votosResourceServer.Controllers;

import com.fgiron.votosResourceServer.Advice.EleccionNotFoundException;
import com.fgiron.votosResourceServer.Models.Eleccion;
import com.fgiron.votosResourceServer.Models.Voto_Partido;
import com.fgiron.votosResourceServer.Repositories.Voto_PartidoRepository;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;

/**
 *
 * @author fgiron
 */
@RestController
public class Voto_PartidoController {
    
    @Autowired
    private final Voto_PartidoRepository repo;
    
    public Voto_PartidoController(Voto_PartidoRepository repo){
        this.repo = repo;
    }
    
    @GetMapping("/partidos")
    public List<Voto_Partido> getAllPartidos(){
        return repo.findAll();
    }
    
    @GetMapping("/partidos/{id}")
    public Voto_Partido getPartidoById(@PathVariable long id) throws EleccionNotFoundException{
        return repo.findById(id)
                .orElseThrow(() -> new EleccionNotFoundException(id));
    }
    
    @PutMapping("/partidos/{id}")
    public Voto_Partido actualizarEleccion(@RequestBody Voto_Partido nuevoPartido, @PathVariable long id) throws Exception{
        return repo.findById(id)
                .map((Voto_Partido partido) -> {
                    partido.setNombre(nuevoPartido.getNombre());
                    return repo.save(partido);
                })
                .orElseThrow(() -> new Exception());
    }
    
    @PostMapping("/partido")
    public Voto_Partido insertarPartido(@RequestBody Voto_Partido nuevoPartido){
        return repo.save(nuevoPartido);
    }
    
    @DeleteMapping("/partido/{id}")
    public void eliminarPartido(@PathVariable long id){
        repo.deleteById(id);
    }
    
}