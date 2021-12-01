/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Controllers;

import com.fgiron.votosResourceServer.Advice.EleccionNotFoundException;
import com.fgiron.votosResourceServer.Models.Integrante;
import com.fgiron.votosResourceServer.Models.Tipo_Eleccion;
import com.fgiron.votosResourceServer.Repositories.IntegranteRepository;
import com.fgiron.votosResourceServer.Repositories.Tipo_EleccionRepository;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 *
 * @author fgiron
 */
@RestController
public class Tipo_EleccionController {
    
    @Autowired
    private final Tipo_EleccionRepository repo;
    
    public Tipo_EleccionController(Tipo_EleccionRepository repo){
        this.repo = repo;
    }
    
    @GetMapping("/tipo_eleccion")
    public List<Tipo_Eleccion> getAllTipos_Eleccion(){
        return repo.findAll();
    }
    
    @GetMapping("/tipo_eleccion/{id}")
    public Tipo_Eleccion getTipo_EleccionById(@PathVariable long id) throws EleccionNotFoundException{
        return repo.findById(id)
                .orElseThrow(() -> new EleccionNotFoundException(id));
    }
    
    @PutMapping("/tipo_eleccion/{id}")
    public Tipo_Eleccion actualizarTipo_Eleccion(@RequestBody Tipo_Eleccion nuevoTipo, @PathVariable long id) throws Exception{
        return repo.findById(id)
                .map((Tipo_Eleccion tipo) -> {
                    tipo.setTipo_eleccion(nuevoTipo.getTipo_eleccion());
                    return repo.save(tipo);
                })
                .orElseThrow(() -> new Exception());
    }
    
    @PostMapping("/tipo_eleccion")
    public Tipo_Eleccion insertarTipo_Eleccion(@RequestBody Tipo_Eleccion nuevoTipo){
        return repo.save(nuevoTipo);
    }
    
    @DeleteMapping("/tipo_eleccion/{id}")
    public void eliminarTipo_Eleccion(@PathVariable long id){
        repo.deleteById(id);
    }
    
}
