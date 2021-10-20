package com.fgiron.votosResourceServer.Controllers;

import com.fgiron.votosResourceServer.Advice.EleccionNotFoundException;
import com.fgiron.votosResourceServer.Models.Eleccion;
import com.fgiron.votosResourceServer.Repositories.EleccionRepository;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 *
 * @author root
 */

@RestController
public class EleccionController {

    private final EleccionRepository repo;
    
    public EleccionController(EleccionRepository repo){
        this.repo = repo;
    }
    
    @GetMapping("/elecciones")
    public List<Eleccion> getAllElecciones(){
        return repo.findAll();
    }
    
    @GetMapping("/eleccion/{id}")
    public Eleccion getEleccionById(@PathVariable long id) throws EleccionNotFoundException{
        return repo.findById(id)
                .orElseThrow(() -> new EleccionNotFoundException(id));
    }
    
    @PutMapping("/eleccion/{id}")
    public Eleccion actualizarEleccion(@RequestBody Eleccion nuevaEleccion, @PathVariable long id) throws Exception{
        return repo.findById(id)
                .map((Eleccion eleccion) -> {
                    eleccion.setProvincia(nuevaEleccion.getProvincia());
                    eleccion.setInstante_comienzo(nuevaEleccion.getInstante_comienzo());
                    eleccion.setInstante_final(nuevaEleccion.getInstante_final());
                    eleccion.setId_tipo_eleccion(nuevaEleccion.getId_tipo_eleccion());
                    return repo.save(eleccion);
                })
                .orElseThrow(() -> new Exception());
    }
    
    @PostMapping("/eleccion")
    public Eleccion insertarEleccion(@RequestBody Eleccion nuevaEleccion){
        return repo.save(nuevaEleccion);
    }
    
    @DeleteMapping("/eleccion/{id}")
    public void eliminarEleccion(@PathVariable long id){
        repo.deleteById(id);
    }
    
}
