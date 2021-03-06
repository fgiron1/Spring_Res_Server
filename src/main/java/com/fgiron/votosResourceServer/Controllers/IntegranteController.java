package com.fgiron.votosResourceServer.Controllers;

import com.fgiron.votosResourceServer.Advice.EleccionNotFoundException;
import com.fgiron.votosResourceServer.Auth.AuthController;
import com.fgiron.votosResourceServer.Models.Integrante;
import com.fgiron.votosResourceServer.Repositories.IntegranteRepository;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.server.ResponseStatusException;

/**
 *
 * @author root
 */
@RestController
public class IntegranteController {
    
    @Autowired
    private final IntegranteRepository repo;
    
    public IntegranteController(IntegranteRepository repo){
        this.repo = repo;
    }
    
    @GetMapping("/integrantes")
    public List<Integrante> getAllIntegrantes(@AuthenticationPrincipal Jwt jwt){
        
        if(AuthController.checkTokenPermissions(jwt, "integrantes.read")){
            return repo.findAll();
        } else {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        }
    }
    
    @GetMapping("/integrante/{id}")
    public Integrante getEleccionById(@PathVariable long id) throws EleccionNotFoundException{
        return repo.findById(id)
                .orElseThrow(() -> new EleccionNotFoundException(id));
    }
    
    @PutMapping("/integrante/{id}")
    public Integrante actualizarIntegrante(@RequestBody Integrante nuevoIntegrante, @PathVariable long id) throws Exception{
        return repo.findById(id)
                .map((Integrante integrante) -> {
                    integrante.setNombre(nuevoIntegrante.getNombre());
                    integrante.setApellidos(nuevoIntegrante.getApellidos());
                    integrante.setCargo(nuevoIntegrante.getCargo());
                    integrante.setId_partido(nuevoIntegrante.getId_partido());
                    return repo.save(integrante);
                })
                .orElseThrow(() -> new Exception());
    }
    
    @PostMapping("/integrante")
    public Integrante insertarIntegrante(@RequestBody Integrante nuevoIntegrante){
        return repo.save(nuevoIntegrante);
    }
    
    @DeleteMapping("/integrante/{id}")
    public void eliminarIntegrante(@PathVariable long id){
        repo.deleteById(id);
    }
    
}
