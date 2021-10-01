/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Models;

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.ManyToMany;
import javax.persistence.Table;

/**
 *
 * @author root
 */
@Entity
@Table(name = "Votos_senado")
public class Voto_Senado {
    
    private @Id @GeneratedValue Long id;
    
    @ManyToMany(mappedBy = "id",
            targetEntity = Candidato_Senado.class)
    private Candidato_Senado id_senador_1;
    
    @ManyToMany(mappedBy = "id",
            targetEntity = Candidato_Senado.class)
    private Candidato_Senado id_senador_2;
    
    @ManyToMany(mappedBy = "id",
            targetEntity = Candidato_Senado.class)
    private Candidato_Senado id_senador_3;

    public Voto_Senado(Candidato_Senado id_senador_1, Candidato_Senado id_senador_2, Candidato_Senado id_senador_3) {
        this.id_senador_1 = id_senador_1;
        this.id_senador_2 = id_senador_2;
        this.id_senador_3 = id_senador_3;
    }    
    
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Candidato_Senado getId_senador_1() {
        return id_senador_1;
    }

    public void setId_senador_1(Candidato_Senado id_senador_1) {
        this.id_senador_1 = id_senador_1;
    }

    public Candidato_Senado getId_senador_2() {
        return id_senador_2;
    }

    public void setId_senador_2(Candidato_Senado id_senador_2) {
        this.id_senador_2 = id_senador_2;
    }

    public Candidato_Senado getId_senador_3() {
        return id_senador_3;
    }

    public void setId_senador_3(Candidato_Senado id_senador_3) {
        this.id_senador_3 = id_senador_3;
    }
    
    
    
}
