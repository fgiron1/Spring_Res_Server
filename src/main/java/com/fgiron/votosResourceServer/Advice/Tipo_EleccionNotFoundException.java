/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Advice;

/**
 *
 * @author root
 */
public class Tipo_EleccionNotFoundException extends RuntimeException{
    
    public Tipo_EleccionNotFoundException(Long id){
        super("No se ha podido encontrar el tipo de elección solicitado con id: " + id);
    }
    
}
