/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.fgiron.votosResourceServer.Advice;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 *
 * @author root
 */
@ControllerAdvice
public class Voto_PartidoNotFoundAdvice {
    
    @ResponseBody
    @ExceptionHandler(Voto_PartidoNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    String partidoNotFoundHandler(Voto_PartidoNotFoundException e){
        return e.getMessage();
    }
    
}