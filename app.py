from flask import Flask, request
from datetime import datetime, timedelta

app = Flask(__name__)

class parkingAppManager:
    cars_collection = set()
    ticket_id = 0

    @staticmethod
    def carInLotByPlate(plate):
        for current_car in parkingAppManager.cars_collection:
            if current_car.plate == plate:
                return True
        return False

    @staticmethod
    def carInLotByTicketId(ticketId):
        for current_car in parkingAppManager.cars_collection:
            if current_car.ticketId == ticketId:
                return current_car
        return None

    class car:
        def __init__(self, plate, time, ticket, parking_lot_id):
            self.plate = plate
            self.time = time
            self.ticketId = ticket
            self.parking_lot_id = parking_lot_id

    @app.route('/entry', methods=['POST'])
    def entry():
        plate = request.args.get('plate')
        parking_lot = request.args.get('parkingLot')
        if not parkingAppManager.carInLotByPlate(plate):
            parkingAppManager.ticket_id += 1
            new_car = parkingAppManager.car(plate, datetime.now(), parkingAppManager.ticket_id, parking_lot)
            parkingAppManager.cars_collection.add(new_car)
            return f"""
            your ticket ID is: {parkingAppManager.ticket_id}"""
        else:
            return f"""
            error: the car is already in the parking lot"""

    @app.route('/exit', methods=['POST'])
    def exit():
        ticked_id_of_wanted_car = request.args.get('ticketId', type = int)
        current_car = parkingAppManager.carInLotByTicketId(ticked_id_of_wanted_car)
        if not current_car:
            return f"""
            error: the car is not in the parking lot"""
        else:
            total_parked_time_in_minutes = (datetime.now() - current_car.time).total_seconds() // 60
            price = ((total_parked_time_in_minutes // 15) + 1) * 2.5
            parkingAppManager.cars_collection.remove(current_car)
            return f"""
            license plate: {current_car.plate},
            time parked in minutes: {total_parked_time_in_minutes},
            parking lot id: {current_car.parking_lot_id},
            charge: {price}$
            Goodbye !!! """
