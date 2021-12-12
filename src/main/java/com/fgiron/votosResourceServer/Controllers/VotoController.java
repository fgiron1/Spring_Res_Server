package com.fgiron.votosResourceServer.Controllers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fgiron.votosResourceServer.Advice.EleccionNotFoundException;
import com.fgiron.votosResourceServer.Models.Eleccion;
import com.fgiron.votosResourceServer.Models.Voto;
import com.fgiron.votosResourceServer.Repositories.VotoRepository;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

/**
 *
 * @author fgiron
 */

@RestController
public class VotoController {

    @Autowired
    private final VotoRepository repo;
    
    public VotoController(VotoRepository repo){
        this.repo = repo;
    }
    
    @PostMapping(path = "/voto", consumes = {MediaType.APPLICATION_JSON_VALUE})
    public void votar(@RequestBody JsonNode json){

        int id_elecciones = Integer.valueOf(json.get("id_elecciones").asText());
        int id_partido = Integer.valueOf(json.get("id_partido").asText());
        String nombre_1 = json.get("nombre_1").asText();
        String nombre_2 = json.get("nombre_2").asText();
        String nombre_3 = json.get("nombre_3").asText();
        String apellido_1 = json.get("apellido_1").asText();
        String apellido_2 = json.get("apellido_2").asText();
        String apellido_3 = json.get("apellido_3").asText();

        repo.votar(id_elecciones, id_partido, nombre_1, nombre_2, nombre_3, apellido_1, apellido_2, apellido_3);
    }
  
    @PostMapping("/login/oauth2/code")
    public void procesarAuth_Code(){

        

    }

    @PostMapping("/authorized")
    public void recibir_token(@RequestBody String jwt){

    }

}
