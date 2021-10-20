package com.fgiron.votosResourceServer.Advice;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 *
 * @author fgiron
 */

@ControllerAdvice
public class EleccionNotFoundAdvice {
    
    @ResponseBody
    @ExceptionHandler(EleccionNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    String eleccionNotFoundHandler(EleccionNotFoundException e){
        return e.getMessage();
    }
}
