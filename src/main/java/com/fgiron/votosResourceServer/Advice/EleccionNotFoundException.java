/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Advice;

/**
 *
 * @author fgiron
 */


public class EleccionNotFoundException extends RuntimeException {
    
    public EleccionNotFoundException(Long id){
        super("No se ha podido encontrar la elección solicitada de id: " + id);
    }
    
}
