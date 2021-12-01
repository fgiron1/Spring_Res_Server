/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Controllers;

import com.fgiron.votosResourceServer.Models.Voto_Senado;
import com.fgiron.votosResourceServer.Repositories.Voto_SenadoRepository;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;

/**
 *
 * @author fgiron
 */
@RestController
public class Voto_SenadoController {
    
    @Autowired
    private Voto_SenadoRepository repo;
    
    public Voto_SenadoController(Voto_SenadoRepository repo){
        this.repo = repo;
    }
    
    @PostMapping("/voto_senado")
    public Voto_Senado insertarEleccion(@RequestBody Voto_Senado nuevoVoto){
        return repo.save(nuevoVoto);
    }
    
}
