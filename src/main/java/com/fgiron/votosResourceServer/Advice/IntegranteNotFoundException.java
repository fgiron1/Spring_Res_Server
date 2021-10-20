/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Advice;

/**
 *
 * @author root
 */
public class IntegranteNotFoundException extends RuntimeException{
    
    public IntegranteNotFoundException(Long id){
        super("No se ha podido encontrar el integrante de partido solicitado de id: " + id);
    }
    
}
