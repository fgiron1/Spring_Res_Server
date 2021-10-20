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
public class Tipo_EleccionNotFoundAdvice {
    
    @ResponseBody
    @ExceptionHandler(Tipo_EleccionNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    String tipo_EleccionNotFoundHandler(Tipo_EleccionNotFoundException e){
        return e.getMessage();
    }
    
}
